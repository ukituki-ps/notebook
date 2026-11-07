#!/usr/bin/env python3
# gate-graph-actualized: UI-фича обязана быть представлена в UI-графе и он должен быть
# АКТУАЛИЗИРОВАН этим прогоном (иначе модель (archd/UI-граф) разъезжается с кодом — инцидент E3877:
# s04/s21 скипнуты, панель в коде есть, в arch/structure/ui-pages/*.yaml её нет, в archd 0 артефактов).
#
# Проверка детерминированная (git + grep), без сети и YAML-библиотек:
#   1) платформа UI (path1.ui.json platform ∈ web|mobile|both), иначе PASS-NA;
#   2) в ветке есть изменённые UI-файлы (кроме тестов), иначе PASS-NA;
#   3) среди изменённых в этой ветке артефактов графа есть такой, который ссылается хотя бы на один
#      изменённый UI-файл (полным путём или именем компонента) → PASS; иначе FAIL c инструкцией.
#
# Портируемость (ADR-KIT-090 followup): UI-поверхность и пути графа берутся из
# `path1.project.json` (graph.source_roots / graph.artifact_globs), а не хардкодятся под
# archkit (`nexus-ui/**`). Для UI-проекта настроенный-но-отсутствующий корень = FAIL
# (иначе app-репо получал ложный PASS-NA и «зелёный» прогон без графа).
import argparse, fnmatch, os, re, subprocess, sys

_DIR = os.path.dirname(os.path.abspath(__file__))

DEFAULT_SOURCE_ROOTS = ["nexus-ui"]
DEFAULT_ARTIFACT_GLOBS = [
    "arch/structure/ui-pages/*.yaml",
    "arch/structure/ui-pages/*.yml",
    "doc/идеи/*/UI-GRAPH.yaml",
    "doc/идеи/*/UI-GRAPH.yml",
]


def _cfg(root, path, default=None):
    try:
        if _DIR not in sys.path:
            sys.path.insert(0, _DIR)
        import _path1_project as proj  # type: ignore

        v = proj.get(root, path)
        if v is None:
            return default
        return v
    except Exception:
        return default


def sh(root, *args):
    r = subprocess.run(args, cwd=root, capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def ui_platform(root):
    p = os.path.join(root, "path1.ui.json")
    if os.path.isfile(p):
        try:
            txt = open(p, encoding="utf-8").read()
        except OSError:
            txt = ""
        m = re.search(r'"platform"\s*:\s*"([^"]*)"', txt)
        if m:
            return m.group(1).strip().lower()
    # контракт проекта как альтернативный источник (ui.platform)
    v = _cfg(root, "ui.platform", "")
    return str(v or "").strip().lower()


UI_EXT = (".tsx", ".jsx", ".vue", ".css", ".scss", ".less")
TEST_MARK = ("__tests__/", ".test.", ".spec.", "/tests/", "/e2e/", "cypress/")


def is_test(path):
    return any(m in path for m in TEST_MARK)


def comp_name(path):
    base = os.path.basename(path)
    return re.sub(r"\.(tsx|jsx|ts|js|vue|css|scss|less)$", "", base)


def make_is_ui(source_roots):
    """UI-ПОВЕРХНОСТЬ (то, что живёт в графе) под одним из корней проекта.
    Review E8141: playwright.config.ts и tsconfig.tsbuildinfo попадали в «изменённые UI-файлы»
    и заставляли гейт требовать актуализации графа там, где UI не менялся.
    """
    def is_ui(path: str) -> bool:
        if path.endswith((".config.ts", ".config.js", ".tsbuildinfo", ".d.ts")):
            return False
        if not path.endswith(UI_EXT):
            return False
        for r in source_roots:
            r = r.strip("/")
            if path.startswith(r + "/"):
                return True
        return False
    return is_ui


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--execution", default="")
    a = ap.parse_args()
    root = a.root

    plat = ui_platform(root)
    if plat not in ("web", "mobile", "both"):
        print(f"gate-graph-actualized: PASS-NA — platform='{plat or 'none'}' (не UI)")
        return 0

    source_roots = _cfg(root, "graph.source_roots", DEFAULT_SOURCE_ROOTS) or []
    artifact_globs = _cfg(root, "graph.artifact_globs", DEFAULT_ARTIFACT_GLOBS) or []
    source_roots = [str(x) for x in source_roots]
    artifact_globs = [str(x) for x in artifact_globs]

    # UI-проект, но объявленные корни отсутствуют → конфигурация неверна, не «зелёный».
    if source_roots and not any(os.path.isdir(os.path.join(root, r.strip("/"))) for r in source_roots):
        print(
            "gate-graph-actualized: FAIL — platform=UI, но ни один graph.source_roots не существует "
            f"({', '.join(source_roots)}). Поправь path1.project.json (ложный PASS-NA запрещён).",
            file=sys.stderr,
        )
        return 1

    is_ui = make_is_ui(source_roots)

    rc, _ = sh(root, "git", "rev-parse", "--verify", "--quiet", a.base)
    if rc != 0:
        print(f"gate-graph-actualized: FAIL — база {a.base} недоступна (нельзя определить изменения)", file=sys.stderr)
        return 1

    # core.quotepath=false: иначе git отдаёт octal-escape для не-ASCII путей
    # (doc/спецификация/..., doc/идеи/...) и fnmatch не матчит кириллические глобы
    # из path1.project.json → ложный FAIL (баг найден на F003/s21, E5438).
    rc, out = sh(root, "git", "-c", "core.quotepath=false", "diff", "--name-only", f"{a.base}...HEAD")
    if rc != 0:
        print("gate-graph-actualized: FAIL — git diff не выполнился", file=sys.stderr)
        return 1
    changed = [l for l in out.splitlines() if l.strip()]

    required = [f for f in changed if is_ui(f) and not is_test(f)]
    if not required:
        print("gate-graph-actualized: PASS-NA — изменённых UI-файлов (кроме тестов) нет")
        return 0

    cands = [f for f in changed if any(fnmatch.fnmatch(f, g) for g in artifact_globs)]
    if not cands:
        print(
            "gate-graph-actualized: FAIL — UI-фича не отражена в UI-графе: этим прогоном не обновлён ни один\n"
            f"  артефакт графа ({', '.join(artifact_globs)}).\n"
            "  Выполни s21.graph_actualize (graph-builder from-code) и закоммить граф — иначе модель разъедется с кодом.\n"
            f"  Изменённые UI-файлы: {', '.join(required[:6])}{' …' if len(required) > 6 else ''}",
            file=sys.stderr,
        )
        return 1

    for c in cands:
        try:
            txt = open(os.path.join(root, c), encoding="utf-8").read()
        except OSError:
            continue
        hit = [f for f in required if f in txt or comp_name(f) in txt]
        if hit:
            print(f"gate-graph-actualized: OK — {c} актуализирован и ссылается на {', '.join(hit[:3])}"
                  f"{' …' if len(hit) > 3 else ''}")
            return 0

    print(
        "gate-graph-actualized: FAIL — артефакты графа обновлены (" + ", ".join(cands) + "), но НИ ОДИН не\n"
        f"  ссылается на изменённые UI-файлы: {', '.join(required[:6])}. Граф фиктивен/не про эту фичу.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
