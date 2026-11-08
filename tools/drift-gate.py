#!/usr/bin/env python3
"""drift-gate — раннер path-1 v3.

Детерминированный раннер (НЕ LLM): снимок из кода + прогон сценария + сверка expected==actual.

Подкоманды:
  snapshot  --scope <files|dirs...> [--commit <sha>]  → reality-snapshot.json
  run       --scenario <test.py> --stand <url>        → run-result.json
  verify    --expected <canon.json> --actual <run.json> → exit 0/1

Снимок поддерживает два языка:
  • Go   (.go)                 — определения `func` / `type … struct` (правило v3.0)
  • Frontend (.ts/.tsx/.js/.jsx) — компоненты, хуки, сторы, api-клиенты, маршруты, константы

`--scope` принимает как файлы, так и каталоги (каталоги обходятся рекурсивно, мусорные
каталоги пропускаются: node_modules/dist/build/coverage/vendor/.git/.orc-worktrees).
Порядок узлов детерминирован (сортировка обхода) — инвариант §4 п.4 регламента.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

GO_EXT = ('.go',)
TS_EXT = ('.ts', '.tsx', '.js', '.jsx')
SKIP_DIRS = {
    'node_modules', 'dist', 'build', 'coverage', 'vendor', '__pycache__',
    '.git', '.orc-worktrees', '.venv', 'storybook-static',
}


def captured_at():
    """UTC-метка в прежнем формате (…Z), без deprecated utcnow()."""
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).isoformat() + 'Z'


def derive_kind(path, line):
    """Деривация kind узла по правилу (Go, не самозаявление). Поведение v3.0 сохранено."""
    text = line.lower()
    # endpoint: HTTP-обработчик или регистрация маршрута
    if 'servehttp' in text or 'handler' in text:
        return 'endpoint'
    if re.search(r'\.(get|post|put|delete|patch)\(', text) or 'route' in text:
        return 'endpoint'
    # table: SQL-миграция/таблица
    if 'create table' in text or 'create_table' in text:
        return 'table'
    # const: константа
    if text.startswith('const ') or ' = ' in text and text.split('=')[0].strip().isupper():
        return 'const'
    return 'function'


def is_route_file(path):
    """Файл похож на файл маршрутов (для отсечения ложных `path:` в конфигах)."""
    p = path.replace('\\', '/').lower()
    base = os.path.basename(p)
    return ('/routes/' in p or '/router/' in p or base.startswith('routes.')
            or '.routes.' in base or base.endswith('.routes.ts') or base.endswith('.routes.tsx')
            or 'router' in base or base == 'app.tsx')


def is_api_file(path):
    """Файл — клиент API (исходящая контрактная поверхность)."""
    p = path.replace('\\', '/').lower()
    base = os.path.basename(p)
    return ('/api/' in p) or base == 'api.ts' or base.endswith('api.ts')


def derive_kind_ts(path, line, name=None):
    """Деривация kind для TS/TSX-узла (не самозаявление)."""
    text = line.strip()
    if name is not None:
        # маршрут (JSX или объект route-конфига)
        if text.startswith('<Route') or re.search(r'\bpath\s*:', text):
            return 'route'
        if re.search(r'=\s*create(?:Store)?\s*[<(]', text) or re.search(r'=\s*\w*[Ss]tore\(', text):
            return 'store'
        if is_api_file(path):
            return 'client'
        if re.match(r'^use[A-Z]', name):
            return 'hook'
        if re.match(r'^[A-Z]', name) and re.search(r'function|class|=>|\b\(', text):
            return 'component'
        if name.isupper() or re.match(r'^[A-Z][A-Z0-9_]+$', name):
            return 'const'
        if text.startswith('export const') or text.startswith('const '):
            return 'const'
        return 'function'
    return 'function'


def nodes_from_route_consts(path, lines):
    """Константы путей в route-объектах: `ROUTES.ADMIN.ROOT: '/app/admin'` → id `ROUTES.ADMIN.ROOT`.

    Вложенность восстанавливается стеком отступов (line-based, без парсера) — id совпадает
    с тем, как константа используется в коде, поэтому проверка «есть ли живые ссылки» механична.
    """
    out = []
    stack = []  # [(indent, key)]
    for lineno, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith('//') or s.startswith('*') or s.startswith('/*'):
            continue
        indent = len(line) - len(line.lstrip())
        while stack and indent <= stack[-1][0]:
            stack.pop()
        m_obj = re.match(r'^(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*=\s*\{\s*$', s)
        if m_obj:
            stack.append((indent, m_obj.group(1)))
            continue
        m_key_obj = re.match(r'^([A-Za-z_$][\w$]*)\s*:\s*\{\s*$', s)
        if m_key_obj:
            stack.append((indent, m_key_obj.group(1)))
            continue
        m_key_val = re.match(r'^([A-Za-z_$][\w$]*)\s*:\s*[\'"]([^\'"]+)[\'"]', s)
        if m_key_val and m_key_val.group(2).startswith('/'):
            name = '.'.join([k for _, k in stack] + [m_key_val.group(1)])
            out.append({
                'id': name,
                'kind': 'route_const',
                'ref': f'{path}:{lineno}',
                'actual_behavior': s,
                'run_result': None,
            })
    return out


# --- извлечение узлов ------------------------------------------------------

TS_DECL = [
    re.compile(r'^export\s+default\s+(?:async\s+)?function\s+([A-Za-z_$][\w$]*)'),
    re.compile(r'^export\s+(?:default\s+)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)'),
    re.compile(r'^export\s+(?:abstract\s+)?class\s+([A-Za-z_$][\w$]*)'),
    re.compile(r'^export\s+const\s+([A-Za-z_$][\w$]*)\s*=\s*'),
    re.compile(r'^export\s+let\s+([A-Za-z_$][\w$]*)\s*=\s*'),
    re.compile(r'^(?:async\s+)?function\s+([A-Za-z_$][\w$]*)'),
    re.compile(r'^const\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\(|function\b|[A-Za-z_$][\w$]*\s*=>)'),
]
TS_ROUTE_JSX = re.compile(r'<Route\b[^>]*\bpath\s*=\s*[\'"]([^\'"]+)[\'"]')
TS_ROUTE_OBJ = re.compile(r'\bpath\s*:\s*[\'"]([^\'"]+)[\'"]')


def nodes_from_go(path, lines):
    out = []
    for lineno, line in enumerate(lines, 1):
        s = line.strip()
        m = None
        if s.startswith('func '):
            m = re.match(r'func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)', s)
        elif s.startswith('type ') and ' struct' in s:
            m = re.match(r'type\s+(\w+)\s+struct', s)
        if m:
            out.append({
                'id': m.group(1),
                'kind': derive_kind(path, s),
                'ref': f'{path}:{lineno}',
                'actual_behavior': s,
                'run_result': None,
            })
    return out


def nodes_from_ts(path, lines):
    """Узлы TS/TSX: объявления верхнего уровня + маршруты (JSX/route-конфиг/константы путей)."""
    out = []
    route_file = is_route_file(path)
    if route_file:
        out.extend(nodes_from_route_consts(path, lines))
    for lineno, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith('//') or s.startswith('*') or s.startswith('/*'):
            continue
        top_level = line[:1] not in (' ', '\t')

        # маршруты: JSX <Route path="…"> (где угодно) или объект route-конфига { path: '…' } (только route-файлы)
        m = TS_ROUTE_JSX.search(line)
        if m is None and route_file:
            mo = TS_ROUTE_OBJ.search(line)
            if mo and mo.group(1):
                m = mo
        if m is not None:
            out.append({
                'id': m.group(1),
                'kind': 'route',
                'ref': f'{path}:{lineno}',
                'actual_behavior': s,
                'run_result': None,
            })
            continue

        if not top_level:
            continue
        for pat in TS_DECL:
            m = pat.match(s)
            if m:
                name = m.group(1)
                out.append({
                    'id': name,
                    'kind': derive_kind_ts(path, s, name),
                    'ref': f'{path}:{lineno}',
                    'actual_behavior': s,
                    'run_result': None,
                })
                break
    return out


def expand_scope(scope):
    """Файлы + каталоги (рекурсивно), детерминированный порядок, без дублей."""
    out = []
    for entry in scope:
        if os.path.isdir(entry):
            for root, dirs, files in os.walk(entry):
                dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
                for name in sorted(files):
                    if os.path.splitext(name)[1] in GO_EXT + TS_EXT:
                        out.append(os.path.join(root, name))
        elif os.path.isfile(entry):
            out.append(entry)
    seen, uniq = set(), []
    for f in out:
        if f not in seen:
            seen.add(f)
            uniq.append(f)
    return uniq


def snapshot(scope, commit):
    """Извлечь узлы из кода (grep-поиск определений) с ref + kind."""
    files = expand_scope(scope)
    nodes = []
    for f in files:
        if not os.path.exists(f):
            continue
        with open(f, encoding='utf-8', errors='replace') as fh:
            lines = fh.read().splitlines()
        ext = os.path.splitext(f)[1]
        if ext in TS_EXT:
            nodes.extend(nodes_from_ts(f, lines))
        else:
            nodes.extend(nodes_from_go(f, lines))
    return {
        'scope': scope,
        'scope_files': files,
        'commit': commit,
        'captured_at': captured_at(),
        'nodes': nodes,
    }


def run_scenario(scenario, stand):
    """Прогнать сценарий (subprocess) и снять actual_behavior + ci_hash."""
    cmd = ['python3', scenario] if scenario.endswith('.py') else [scenario]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except (subprocess.TimeoutExpired, OSError) as e:
        return {
            'scenario_id': scenario, 'stand': stand,
            'run_at': captured_at(),
            'actual_behavior': f'RUN ERROR: {e}',
            'db_ids': [], 'ci_hash': '',
        }
    actual_behavior = (r.stdout or r.stderr or '').strip()
    ci = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True)
    ci_hash = ci.stdout.strip() if ci.returncode == 0 else ''
    return {
        'scenario_id': scenario, 'stand': stand,
        'run_at': captured_at(),
        'actual_behavior': actual_behavior,
        'db_ids': [], 'ci_hash': ci_hash,
    }


def verify(expected_path, actual_path):
    """Сверка expected_behavior == actual_behavior (fail-close, не 'artifact exists')."""
    with open(expected_path) as f:
        expected = json.load(f)
    with open(actual_path) as f:
        actual = json.load(f)

    exp = expected.get("expected_behavior") or expected.get("expected")
    act = actual.get("actual_behavior")
    ci_hash = actual.get("ci_hash") or (actual.get("evidence") or {}).get("ci_hash")

    # fail-close: пустые значения = доказательства нет (запрет "" == "" → PASS)
    if not exp or not act:
        print("FAIL: expected_behavior или actual_behavior пусто (fail-close, не 'artifact exists')", file=sys.stderr)
        return 1

    # якорь прогона обязателен (иначе «прогон был» не доказан)
    if not ci_hash:
        print("FAIL: ci_hash отсутствует — прогон не доказан", file=sys.stderr)
        return 1

    if exp == act:
        print("PASS: expected_behavior == actual_behavior (ci_hash ok)")
        return 0

    print(f"FAIL: расхождение\n  expected: {exp}\n  actual:   {act}", file=sys.stderr)
    return 1


def main():
    p = argparse.ArgumentParser(description="drift-gate runner (path-1 v3)")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("snapshot")
    sp.add_argument("--scope", nargs="+", required=True,
                    help="файлы и/или каталоги (каталоги обходятся рекурсивно)")
    sp.add_argument("--commit", required=True)

    rp = sub.add_parser("run")
    rp.add_argument("--scenario", required=True)
    rp.add_argument("--stand", required=True)

    vp = sub.add_parser("verify")
    vp.add_argument("--expected", required=True)
    vp.add_argument("--actual", required=True)

    a = p.parse_args()
    if a.cmd == "snapshot":
        print(json.dumps(snapshot(a.scope, a.commit), indent=2, ensure_ascii=False))
    elif a.cmd == "run":
        print(json.dumps(run_scenario(a.scenario, a.stand), indent=2, ensure_ascii=False))
    elif a.cmd == "verify":
        sys.exit(verify(a.expected, a.actual))


if __name__ == "__main__":
    main()
