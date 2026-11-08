#!/usr/bin/env bash
# gate-code-review (s22c, ADR-KIT-090) — машинная приёмка адверсариального код-ревью.
# Падает, если: нет code-review.json; ревью пустое; нет proof того, что ревьюер
# ЗАПУСКАЛ код/тесты; есть НЕзакрытые critical/high с verdict=confirmed.
# $1 = execution_id (опц.).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
# idea_file <relname> — артефакт ТЕКУЩЕЙ фичи (детерминированно; не «первый по glob»).
idea_file() { python3 "$DIR/_feature_dir.py" --root "$ROOT" --name "$1" 2>/dev/null; }
fail() { echo "gate-code-review: FAIL — $1" >&2; exit 1; }
# F12 (E6513): запрет правки гейтов/тулинга в ветке прогона.
bash "$DIR/check-tools-untouched.sh" || exit 1

rev="$(idea_file code-review.json)"
[ -n "$rev" ] || fail "нет code-review.json (шаг s22c не выполнен)"

python3 - "$rev" "$DIR/model-policy.json" <<'PY' || exit 1
import json, sys, os
p = sys.argv[1]
pol_path = sys.argv[2] if len(sys.argv) > 2 else ""
d = json.load(open(p, encoding="utf-8"))
reviewer = d.get("reviewer") or {}
rmodel = str(reviewer.get("model", "") if isinstance(reviewer, dict) else "").strip()
rprov  = str(reviewer.get("provider", "") if isinstance(reviewer, dict) else "").strip()
if not rmodel:
    print("gate-code-review: FAIL — не указан reviewer.model (нужна независимая модель)", file=sys.stderr); sys.exit(1)
# ADR-KIT-090 model-distinct: кросс-пара дешёвых моделей (author ↔ reviewer).
amodel = str(d.get("author_model") or os.environ.get("AUTHOR_MODEL") or "").strip()
aprov  = str(d.get("author_provider") or os.environ.get("AUTHOR_PROVIDER") or "").strip()
if not amodel:
    print("gate-code-review: FAIL — нет author_model (поле code-review.json или env AUTHOR_MODEL)", file=sys.stderr); sys.exit(1)
def prov_of(m, p):
    if p: return p
    if "/" in m: return m.split("/")[0]
    ml = m.lower()
    if "qwen" in ml: return "llama-proxy"
    if "deepseek" in ml: return "deepseek"
    return ""
base = lambda m: m.split("/")[-1]
ap, rp = prov_of(amodel, aprov), prov_of(rmodel, rprov)
if ap and rp and ap == rp:
    print(f"gate-code-review: FAIL — reviewer.provider == author.provider ({ap}); нужна другая модель/провайдер", file=sys.stderr); sys.exit(1)
if base(rmodel) == base(amodel):
    print(f"gate-code-review: FAIL — reviewer.model == author_model ({amodel}); ревью не независимо", file=sys.stderr); sys.exit(1)
# проверка соответствия объявленной паре (если политика есть и провайдер автора известен)
if pol_path and os.path.exists(pol_path) and ap:
    pol = json.load(open(pol_path, encoding="utf-8"))
    match = [pr for pr in pol.get("pairs", []) if pr.get("author_provider") == ap]
    if match:
        exp = match[0]
        if rp and rp != exp["reviewer_provider"]:
            print(f"gate-code-review: FAIL — reviewer.provider={rp}, ожидается {exp['reviewer_provider']} (пара для автора {ap})", file=sys.stderr); sys.exit(1)
        if exp["reviewer_model"].lower() not in base(rmodel).lower():
            print(f"gate-code-review: FAIL — reviewer.model={base(rmodel)}, ожидается '{exp['reviewer_model']}' (пара для автора {ap})", file=sys.stderr); sys.exit(1)
findings = d.get("findings") or []
proofs = d.get("proofs") or d.get("proof_run_ids") or []
if not proofs:
    print("gate-code-review: FAIL — нет proof (ревьюер не запускал код/тесты)", file=sys.stderr); sys.exit(1)
if not findings:
    print("gate-code-review: FAIL — пустой findings (ревью не проводилось)", file=sys.stderr); sys.exit(1)
bad = [f for f in findings
       if str(f.get("verdict", "")).lower() == "confirmed"
       and str(f.get("severity", "")).lower() in ("critical", "high")]
if bad:
    for f in bad:
        print(f"gate-code-review: FAIL — открытая находка {f.get('id')} [{f.get('severity')}] {f.get('file_line','')}",
              file=sys.stderr)
    sys.exit(1)
hi = sum(1 for f in findings if str(f.get("severity","")).lower() in ("critical","high"))
# ADR-KIT-090 executor-distinct по СЕССИИ: ревью обязан сделать отдельный агент-ревьюер.
# E9236: артефакт объявлял кросс-пару (qwen), но qwen-сессии не было — ревью сделал сам
# team-lead. Проверяем явную связку сессий (self-review запрещён).
author_sess = str(d.get("author_session_id") or d.get("session_id") or "").strip()
reviewer_sess = str(d.get("reviewer_session_id") or "").strip()
if not reviewer_sess:
    print("gate-code-review: FAIL — нет reviewer_session_id (нужна сессия независимого ревьюера)", file=sys.stderr); sys.exit(1)
if not author_sess:
    print("gate-code-review: FAIL — нет author_session_id/session_id (нельзя доказать независимость)", file=sys.stderr); sys.exit(1)
if reviewer_sess == author_sess:
    print(f"gate-code-review: FAIL — reviewer_session_id == author session ({reviewer_sess}); ревью не независимо (самопроверка)", file=sys.stderr); sys.exit(1)
# F9 (E3473): строковое неравенство обходится подделкой — несуществующий
# reviewer_session_id ("ses_eb_s22c_reviewer_1650") и execution-id в поле author.
# Требуем РЕАЛЬНЫЙ формат id сессии (ses_<alnum>, как у настоящих ses_eb2001d7…).
import re as _re
_sess_pat = _re.compile(r"^ses_[A-Za-z0-9]{16,}$")
for _name, _val in (("author_session_id", author_sess), ("reviewer_session_id", reviewer_sess)):
    if not _sess_pat.match(_val):
        print(f"gate-code-review: FAIL — {_name}={_val!r} не является реальным id сессии (ожидается ses_<alnum>{'{16,}'}); "
              f"подделка/execution-id вместо сессии запрещены (F9)", file=sys.stderr); sys.exit(1)

print(f"gate-code-review: OK — author={base(amodel)}({ap}) -> reviewer={base(rmodel)}({rp}), findings={len(findings)} (high+={hi}, все closed/refuted), proofs={len(proofs)}, reviewer_session={reviewer_sess[:12]}…")
PY
