#!/usr/bin/env python3
"""gate-evidence-durable — доказательства прогона обязаны быть durable и repo-relative.

Причина (аудит F003/E5438): `scenario-evidence.json` ссылался на e2e_ref
`/home/ukituki/kh_pg/.e2e-artifacts/E5438-093138` (пустой каталог на хосте, вне репо),
`preview-*.json` жили только в ворктри прогона — постфактум проверить, к какому билду
относится доказательство, невозможно. Плюс первые кадры мобильной пробы не попали в
артефакты, а evidence ссылался на несуществующие файлы.

Проверки (fail-close):
  R1  ссылки на артефакты внутри evidence-файлов не могут быть абсолютными путями
      (`/home/...`, `/tmp/...`, `/app/...`) — доказательство обязано лежать в репо;
  R2  каждая repo-relative ссылка существует на диске;
  R3  если есть <feature>/evidence/MANIFEST.json — sha256/размер каждого файла совпадают;
  R4  с --require-manifest: манифест обязателен (гейт s24 после экспорта прогона).

Пути-исключения: run-артефакты (preview-deploy.json/preview-verdict.json) в чистом
checkout ветки отсутствуют штатно → warn, а с --strict-run-refs — FAIL (режим прогона).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

# Поля-ссылки на артефакты (в них допустим ТОЛЬКО repo-relative путь).
REF_KEYS = {
    "screenshot", "screenshots", "e2e_ref", "artifact", "artifacts",
    "artifact_path", "file", "shot", "shot_path", "evidence_ref",
}
# Поля, где путь может быть host-локальным по природе (команды, логи раннера) — не проверяем.
SKIP_KEYS = {"command", "cmd", "stdout_ref", "stderr_ref", "log", "url", "source"}
# Run-артефакты: есть в ворктри прогона, нет в ветке.
RUN_ARTIFACTS = ("preview-deploy.json", "preview-verdict.json")
ABS_RE = re.compile(r"^(?:/|~|[A-Za-z]:\\)")
REL_RE = re.compile(r"[\w./\u0400-\u04FF-]+\.[A-Za-z0-9]{1,6}$")


def _is_evidence_name(name: str) -> bool:
    return name.endswith(".json") and (
        name.startswith(("scenario-evidence", "mobile-evidence", "preview-", "result-audit",
                         "ui-audit", "fault-verdicts", "code-review"))
        or name == "MANIFEST.json"
    )


def _sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _walk_refs(node, key=None):
    """Итератор (key, value) по полям-ссылкам."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in REF_KEYS:
                yield k, v
            elif k not in SKIP_KEYS:
                yield from _walk_refs(v, k)
    elif isinstance(node, list):
        for item in node:
            yield from _walk_refs(item, key)


def _refs(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for v in value:
            yield from _refs(v)
    elif isinstance(value, dict):
        for v in value.values():
            yield from _refs(v)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="gate-evidence-durable")
    ap.add_argument("--root", required=True)
    ap.add_argument("--feature-dir", default="", help="каталог фичи (иначе — все doc/идеи/*)")
    ap.add_argument("--require-manifest", action="store_true")
    ap.add_argument("--strict-run-refs", action="store_true",
                    help="run-артефакты обязаны существовать (режим прогона/экспорта)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    root = os.path.abspath(a.root)
    dirs = []
    if a.feature_dir:
        dirs = [os.path.abspath(a.feature_dir)]
    else:
        base = os.path.join(root, "doc", "идеи")
        if os.path.isdir(base):
            dirs = [os.path.join(base, d) for d in sorted(os.listdir(base))
                    if os.path.isdir(os.path.join(base, d))]

    errors: list[str] = []
    warns: list[str] = []
    checked = 0
    manifests = 0

    def rel(p: str) -> str:
        return os.path.relpath(p, root)

    for fd in dirs:
        if not os.path.isdir(fd):
            continue
        files = []
        for dirpath, _dirs, names in os.walk(fd):
            for n in names:
                if _is_evidence_name(n):
                    files.append(os.path.join(dirpath, n))
        for path in sorted(files):
            try:
                data = json.load(open(path, encoding="utf-8"))
            except (OSError, ValueError):
                continue  # не JSON-артефакт — не наша зона (валидируют другие гейты)
            checked += 1
            base_name = os.path.basename(path)
            is_manifest = base_name == "MANIFEST.json"
            if is_manifest:
                manifests += 1
            for key, value in _walk_refs(data):
                for ref in _refs(value):
                    if not isinstance(ref, str) or not ref.strip():
                        continue
                    r = ref.strip()
                    # R1: абсолютный путь в ссылке на артефакт
                    if ABS_RE.match(r):
                        if any(r.endswith(x) for x in RUN_ARTIFACTS):
                            (errors if a.strict_run_refs else warns).append(
                                f"{rel(path)}: {key}='{r}' — run-артефакт по host-пути "
                                f"(экспортируй прогон: tools/export-run-evidence.sh)")
                        else:
                            errors.append(
                                f"{rel(path)}: {key}='{r}' — абсолютный host-путь "
                                f"(доказательство обязано быть repo-relative)")
                        continue
                    # MANIFEST: сам список путей проверяем отдельно (R3)
                    if is_manifest:
                        continue
                    if not REL_RE.search(r):
                        continue
                    # R2: существование repo-relative ссылки
                    cand = os.path.join(root, r)
                    if not os.path.exists(cand):
                        if r.startswith(("tools/", "scripts/", "deploy/stands/", "data/audit/")):
                            # путь доставляется китом/прогоном: в checkout ветки его нет штатно
                            warns.append(f"{rel(path)}: {key}='{r}' — нет в checkout (к ит/прогон)")
                        elif os.path.basename(r) in RUN_ARTIFACTS:
                            (errors if a.strict_run_refs else warns).append(
                                f"{rel(path)}: {key}='{r}' — run-артефакт недоступен "
                                f"(в ветке его нет штатно)")
                        else:
                            errors.append(f"{rel(path)}: {key}='{r}' — файл не найден в репо")
            # проверим только ссылки ВНУТРИ проанализированного файла

        # R3: MANIFEST(ы) — целостность перечисленных файлов (evidence/MANIFEST.json и
        # evidence/run-<E>/MANIFEST.json — куда пишет export-run-evidence.sh).
        import glob as _glob
        mans = sorted(_glob.glob(os.path.join(fd, "evidence", "**", "MANIFEST.json"), recursive=True))
        found_manifest = bool(mans)
        for man in mans:
            try:
                m = json.load(open(man, encoding="utf-8"))
            except (OSError, ValueError) as e:
                errors.append(f"{rel(man)}: не читается ({e})")
                continue
            evroot = os.path.dirname(man)
            for entry in (m.get("files", []) or []):
                rp = entry.get("path") or ""
                fp = os.path.join(evroot, rp) if rp else ""
                if not rp or not os.path.isfile(fp):
                    errors.append(f"{rel(man)}: '{rp}' — файл манифеста не найден")
                    continue
                want = entry.get("sha256")
                got = _sha256(fp)
                if want and want != got:
                    errors.append(f"{rel(man)}: '{rp}' sha256={got} != {want} (манифест не сходится)")
        if not found_manifest and a.require_manifest and checked:
            errors.append(
                "нет evidence/**/MANIFEST.json — доказательства прогона не экспортированы "
                "(tools/export-run-evidence.sh <execution_id>)")

    if not checked:
        print("gate-evidence-durable: PASS-NA — evidence-артефактов не найдено")
        return 0
    if a.json:
        print(json.dumps({"gate": "evidence-durable", "ok": not errors, "checked": checked,
                          "manifests": manifests, "errors": errors, "warnings": warns},
                         ensure_ascii=False))
    else:
        for w in warns:
            print(f"gate-evidence-durable: warn — {w}")
        for e in errors:
            print(f"gate-evidence-durable: FAIL — {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
