#!/usr/bin/env bash
# gate-evidence-authentic (ADR-KIT-090) — подлинность доказательств прогона.
# Контейнер-безопасно. Падает, если:
#   1) скриншоты ТЕКУЩЕГО прогона (scenario-evidence + E2E этого execution)
#      дублируются (одинаковый md5/near-dup у разных сценариев) или тривиальны;
#   2) scenario-evidence: не каждый pass подкреплён существующим уникальным скриншотом;
#   2b) evidence-manifest.json: заверение sha256 изменено/непереносимо (абсолютные пути);
#   3) preview-verdict.ref устарел — после него менялись НЕ-доковые/НЕ-evidence файлы;
#   4) нет proof реального исполнения детекторов (fault-catalog --execute).
# Все нарушения собираются за один прогон (полный вывод, без fail-fast на первом).
# Исторический архив <feature>/screenshots прошлых прогонов не судится.
# $1 = execution_id (не обязателен для 1-3).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В pinned gate-bundle DIR=/opt/gate-tools/tools, оцениваемое дерево — ORC_GATE_ROOT.
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
# Canonical per-run evidence: F-RUN-02b persists s20c artifacts under the
# execution root (outside git). The eval worktree is recreated from git at
# accept time and may contain an older committed manifest/screenshots, so the
# run copy MUST win (E1688: 9-file manifest vs 6-file committed).
EXEC_ROOT="${ORC_EXECUTION_ROOT:-$(dirname "$ROOT")}"
# idea_file <relname> — артефакт ТЕКУЩЕЙ фичи (детерминированно; не «первый по glob»).
idea_file() { python3 "$DIR/_feature_dir.py" --root "$ROOT" --name "$1" 2>/dev/null; }
fail() { echo "gate-evidence-authentic: FAIL — $1" >&2; exit 1; }
# E8267: собрать ВСЕ нарушения, а не только первое — приёмка должна видеть
# полную картину (исторические дубли + заверение + proof) за один прогон.
FAILS=()
record() { echo "gate-evidence-authentic: FAIL — $1" >&2; FAILS+=("$1"); }
# F12 (E6513): запрет правки гейтов/тулинга в ветке прогона.
bash "$DIR/check-tools-untouched.sh" || exit 1

# F-RUN-02 (E7141): per-run артефакты не в git (симметрично gate-preview-deploy).
bash "$DIR/check-run-artifacts.sh" "$ROOT" >/dev/null 2>&1 || { bash "$DIR/check-run-artifacts.sh" "$ROOT" >&2 || true; exit 1; }
EXEC="${1:-${EXECUTION_ID:-}}"

# PASS-NA по UI-доказательствам (E7141/F193): backend-only инкремент не может дать UI-E2E.
# Proof детекторов (раздел 4) при этом ОБЯЗАТЕЛЕН. Fail-closed: не определили — проверяем строго.
_ui_rc=0; _ui_reason="$(python3 "$DIR/ui_surface.py" --root "$ROOT" --base "${UI_SURFACE_BASE:-origin/main}" --print-reason 2>/dev/null)" || _ui_rc=$?
if [ "$_ui_rc" = "1" ]; then
  echo "gate-evidence-authentic: PASS-NA (UI-доказательства) — ${_ui_reason:-нет изменённых UI-файлов}; проверяю только proof детекторов"
else

# Каталог ТЕКУЩЕЙ фичи: доказательства чужой фичи/прогона не принимаются
# (инцидент E2389: гейт ловил near-dup из F188 и брал proof прогона F188-v11).
_fd="$(python3 "$DIR/_feature_dir.py" --root "$ROOT" --name scenarios.json 2>/dev/null || true)"
[ -n "$_fd" ] || _fd="$(python3 "$DIR/_feature_dir.py" --root "$ROOT" --name scenario-evidence.json 2>/dev/null || true)"
if [ -z "$_fd" ] && [ -n "${ORC_FEATURE_DIR:-}" ]; then
  case "$ORC_FEATURE_DIR" in
    /*) _cand="$ORC_FEATURE_DIR/scenarios.json" ;;
    *) _cand="$ROOT/$ORC_FEATURE_DIR/scenarios.json" ;;
  esac
  [ -f "$_cand" ] || _cand="$EXEC_ROOT/${ORC_FEATURE_DIR#/}/scenarios.json"
  [ -f "$_cand" ] && _fd="$_cand"
fi
[ -n "$_fd" ] || _fd="$(python3 "$DIR/_feature_dir.py" --root "$EXEC_ROOT" --name scenarios.json 2>/dev/null || true)"
[ -n "$_fd" ] || fail "не определён каталог текущей фичи (нет scenarios.json/scenario-evidence.json)"
FD="$(dirname "$_fd")"
case "$FD" in
  "$ROOT"/*) FD_REL="${FD#"$ROOT"/}" ;;
  "$EXEC_ROOT"/*) FD_REL="${FD#"$EXEC_ROOT"/}" ;;
  *) FD_REL="" ;;
esac
cur() { # cur <relname>: canonical exec-root copy → feature dir → repo root
  local rel="$1"
  if [ -n "${FD_REL:-}" ] && [ -f "$EXEC_ROOT/$FD_REL/$rel" ]; then printf '%s' "$EXEC_ROOT/$FD_REL/$rel"; return; fi
  if [ -f "$EXEC_ROOT/$rel" ]; then printf '%s' "$EXEC_ROOT/$rel"; return; fi
  if [ -f "$FD/$rel" ]; then printf '%s' "$FD/$rel"; return; fi
  if [ -f "$ROOT/$rel" ]; then printf '%s' "$ROOT/$rel"; fi
}

# ── 1. Скриншоты: уникальность + нетривиальность ────────────────────────────
# E8267: судить нужно доказательства ТЕКУЩЕГО прогона, а не весь исторический
# архив screenshots/. В f002.4 накопилось 700+ кадров прошлых прогонов; их
# md5-дубли не имеют отношения к приёмке и давали ложный fail. Берём только
# кадры, на которые ссылается scenario-evidence, плюс E2E-артефакты этого
# исполнения. Оракул уникальности/нетривиальности не ослаблен: он применяется
# к актуальному набору доказательств.
ev="$(cur scenario-evidence.json)"
[ -n "$ev" ] || fail "нет scenario-evidence.json"
refs_file="$(mktemp)"
trap 'rm -f "$refs_file"' EXIT
python3 - "$ev" "$ROOT" "$EXEC_ROOT" >"$refs_file" <<'PY' || exit 1
import json, os, sys
ev, root, execroot = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(ev, encoding="utf-8"))
items = d.get("scenarios") or d.get("items") or []
seen = set()
def emit(p):
    cands = [p] if os.path.isabs(p) else [os.path.join(execroot, p), os.path.join(root, p)]
    for ap in cands:
        if os.path.exists(ap) and ap not in seen:
            seen.add(ap)
            print(ap)
            return
for it in items:
    s = it.get("screenshot") or it.get("evidence") or ""
    if s:
        emit(s)
    evd = it.get("evidence")
    if isinstance(evd, dict):
        for extra in evd.get("screenshots") or []:
            if isinstance(extra, str) and extra:
                emit(extra)
PY
shots=()
while IFS= read -r p; do [ -n "$p" ] && shots+=("$p"); done <"$refs_file"
if [ -n "$EXEC" ]; then
  for f in "$EXEC_ROOT"/.e2e-artifacts/*"$EXEC"*/*.png "$ROOT"/.e2e-artifacts/*"$EXEC"*/*.png; do
    [ -e "$f" ] && shots+=("$f")
  done
fi
if [ "${#shots[@]}" -eq 0 ]; then
  record "нет E2E-скриншотов текущего прогона (scenario-evidence не ссылается ни на один существующий кадр)"
else
  dups="$(md5sum "${shots[@]}" | awk '{print $1}' | sort | uniq -d)"
  [ -z "$dups" ] || record "дублирующиеся скриншоты (разные сценарии дали один PNG): $(echo "$dups" | tr '\n' ' ')"
  for f in "${shots[@]}"; do
    sz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
    [ "$sz" -ge 5000 ] || record "скриншот пуст/тривиален (<5KB): $f ($sz B)"
  done
  # 1b. near-duplicate (md5 не ловит почти одинаковые кадры; см. F188/NF1)
  if [ "${#shots[@]}" -ge 2 ]; then
    python3 "$DIR/pngdiff.py" --thresh 0.005 "${shots[@]}" || record "near-duplicate скриншоты (кадры почти идентичны — не доказательство)"
  fi
fi

# ── 2. scenario-evidence: pass ⇒ существующий уникальный скриншот ───────────
if ! _sc_out="$(python3 - "$ev" "$ROOT" "$EXEC_ROOT" <<'PY' 2>&1
import json, os, sys, hashlib
ev, root, execroot = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(ev, encoding="utf-8"))
items = d.get("scenarios") or d.get("items") or []
seen = {}
bad = []
for it in items:
    sid = it.get("id") or it.get("scenario") or "?"
    st = (it.get("status") or "").lower()
    if st not in ("pass", "passed"):
        bad.append(f"сценарий {sid} status={st!r}"); continue
    # oracle=unit: сценарий закрыт ЮНИТ-оракулом (состояние недостижимо на стенде) —
    # стендовый кадр не требуется, но обязателен существующий test_ref.
    if str(it.get("oracle") or "").strip().lower() == "unit":
        tref = str(it.get("test_ref") or "").strip()
        tf = tref.split("::", 1)[0].strip()
        if not tf:
            bad.append(f"{sid}: oracle=unit без существующего test_ref ({tref!r})"); continue
        if not os.path.isabs(tf):
            if not (os.path.exists(os.path.join(execroot, tf)) or os.path.exists(os.path.join(root, tf))):
                bad.append(f"{sid}: oracle=unit без существующего test_ref ({tref!r})")
        elif not os.path.exists(tf):
            bad.append(f"{sid}: oracle=unit без существующего test_ref ({tref!r})")
        continue
    shot = it.get("screenshot") or it.get("evidence") or ""
    if not shot:
        bad.append(f"сценарий {sid} без screenshot"); continue
    cands = [shot] if os.path.isabs(shot) else [os.path.join(execroot, shot), os.path.join(root, shot)]
    p = next((x for x in cands if os.path.exists(x)), None)
    if not p:
        bad.append(f"screenshot не найден: {shot}"); continue
    h = hashlib.md5(open(p, "rb").read()).hexdigest()
    if h in seen:
        bad.append(f"{sid} и {seen[h]} ссылаются на один скриншот")
        continue
    seen[h] = sid
if bad:
    for b in bad:
        print(f"gate-evidence-authentic: FAIL — {b}", file=sys.stderr)
    sys.exit(1)
print(f"gate-evidence-authentic: scenario-evidence OK ({len(items)} сценариев, уникальные скриншоты)")
PY
)"; then
  echo "$_sc_out" >&2
  record "scenario-evidence: проверки не прошли (полный список выше)"
else
  echo "$_sc_out"
fi

# ── 2b. Заверение evidence (F9b/E3473): манифест sha256 + якорь в preview-verdict ──
# s20c пишет evidence-manifest.json (sha256 скриншотов + scenario-evidence) и
# якорит его sha в preview-verdict.json. Проверяем, что evidence НЕ переписан
# между s20c и s24 (инцидент: s24 переписал SC-1..3 + scenario-evidence → гейты
# прошли; теперь изменение ловится).
man="$(cur evidence-manifest.json)"
if [ -z "$man" ]; then
  record "нет evidence-manifest.json (evidence не заверён; s20c обязан его писать — F9b)"
elif ! _man_out="$(python3 - "$man" "$ROOT" "$EXEC_ROOT" <<'PY' 2>&1
import hashlib, json, os, sys
man, root, execroot = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(man, encoding="utf-8")).get("files") or {}
if not d:
    print("gate-evidence-authentic: FAIL — evidence-manifest.json пуст", file=sys.stderr); sys.exit(1)
bad = []
for rel, want in d.items():
    if os.path.isabs(rel):
        # E8267: манифест, записанный из author-worktree, нёс абсолютные пути
        # (/tmp/kilo/...): на ORC-хосте их нет, заверение непереносимо. Это
        # дефект s20c, а не «файл отсутствует» — сообщаем явно.
        bad.append(f"{rel}: абсолютный путь (манифест обязан писать repo-relative)")
        continue
    cands = [os.path.join(execroot, rel), os.path.join(root, rel)]
    p = next((x for x in cands if os.path.exists(x)), None)
    if not p:
        bad.append(f"{rel}: отсутствует"); continue
    if hashlib.sha256(open(p, "rb").read()).hexdigest() != want:
        bad.append(f"{rel}: sha256 изменён после s20c")
if bad:
    print("gate-evidence-authentic: FAIL — evidence изменён после заверения: " + "; ".join(bad), file=sys.stderr); sys.exit(1)
print(f"gate-evidence-authentic: evidence-manifest OK ({len(d)} файлов)")
PY
)"; then
  echo "$_man_out" >&2
  record "evidence-manifest: заверение не прошло (полный список выше)"
else
  echo "$_man_out"
fi
pv="$(cur preview-verdict.json)"
if [ -n "$pv" ]; then
  _mode="$(python3 -c 'import json,sys;print((json.load(open(sys.argv[1])).get("mode") or "").lower())' "$pv" 2>/dev/null || true)"
  if [ "$_mode" = "api" ]; then
    # API-only E2E has no screenshot/manifest anchor: the verdict anchors the
    # E2E stdout digest (e2e-report.json.artifact_digest). Validate that binding
    # instead of comparing against a manifest this mode never wrote.
    _exroot="${ORC_EXECUTION_ROOT:-$(dirname "$ROOT")}"
    er="$_exroot/e2e-report.json"
    [ -f "$er" ] || er="$FD/e2e-report.json"
    if [ ! -f "$er" ]; then
      record "api-режим: нет e2e-report.json (verdict не заверён)"
    elif ! python3 - "$er" "$pv" <<'PY'
import json, sys
rep, pv = sys.argv[1], sys.argv[2]
r = json.load(open(rep, encoding="utf-8"))
v = json.load(open(pv, encoding="utf-8"))
ad = str(v.get("artifact_digest") or "").strip().lower()
em = str(v.get("evidence_manifest_sha256") or "").strip().lower()
if not ad:
    print("gate-evidence-authentic: FAIL — api-verdict без artifact_digest", file=sys.stderr); sys.exit(1)
if em and em != ad:
    print(f"gate-evidence-authentic: FAIL — api-verdict artifact_digest={ad} != evidence_manifest_sha256={em}", file=sys.stderr); sys.exit(1)
if str(r.get("artifact_digest") or "").strip().lower() != ad:
    print("gate-evidence-authentic: FAIL — e2e-report.artifact_digest != preview-verdict.artifact_digest", file=sys.stderr); sys.exit(1)
if int(r.get("exit_code", 1)) != 0:
    print(f"gate-evidence-authentic: FAIL — api E2E exit_code={r.get('exit_code')}", file=sys.stderr); sys.exit(1)
print("gate-evidence-authentic: api-verdict OK (e2e-report digest bound)")
PY
    then
      record "api-режим: e2e-report не совпадает с preview-verdict"
    fi
  elif [ -n "$man" ]; then
    want="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("evidence_manifest_sha256",""))' "$pv" 2>/dev/null || true)"
    if [ -n "$want" ]; then
      got="$(sha256sum "$man" | awk '{print $1}')"
      [ "$want" = "$got" ] || record "evidence-manifest.json изменён после s20c (sha не совпадает с preview-verdict)"
    fi
  fi
fi

# ── 3. preview-verdict.ref не устарел (только доковые изменения допустимы) ──
pv="$(cur preview-verdict.json)"
if [ -f "$pv" ]; then
  ref="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("ref",""))' "$pv" 2>/dev/null)"
  if [ -n "$ref" ]; then
    changed="$(git -C "$ROOT" -c core.quotepath=false diff --name-only "${ref}..HEAD" 2>/dev/null | grep -vE '\.md$|^doc/|^docs/|^orc/|^tools/|^artifacts/|^preview-deploy\.json$|^preview-verdict\.json$|^\.e2e-artifacts/|^data/audit/runs/|tsbuildinfo|^\.gitignore$|^\.gitattributes$' || true)"
    [ -z "$changed" ] || record "preview-verdict.ref=$ref устарел — после него изменён код: $(echo "$changed" | tr '\n' ' ' | cut -c1-160)"
  fi
fi

fi

# ── 4. proof реального исполнения детекторов ────────────────────────────────
proof=""
if [ -n "$EXEC" ]; then
  # canonical per-run proof lives in the execution root; worktree copy is legacy
  _exroot="${ORC_EXECUTION_ROOT:-$(dirname "$ROOT")}"
  proof="$(ls "$_exroot"/data/audit/runs/*"$EXEC"*/proof*.json "$_exroot"/data/audit/runs/*"$EXEC"*/*/proof*.json 2>/dev/null | head -1 || true)"
  [ -n "$proof" ] || proof="$(ls "$ROOT"/data/audit/runs/*"$EXEC"*/proof*.json "$ROOT"/data/audit/runs/*"$EXEC"*/*/proof*.json 2>/dev/null | head -1 || true)"
fi
if [ -z "$proof" ] && [ -z "$EXEC" ]; then
  _n="$(ls -d "$ROOT"/data/audit/runs/*/ 2>/dev/null | wc -l)"
  [ "$_n" -eq 1 ] && proof="$(ls "$ROOT"/data/audit/runs/*/proof*.json 2>/dev/null | head -1 || true)"
fi
if [ -z "$proof" ]; then
  record "нет proof детекторов для прогона ${EXEC:-?} (ожидается data/audit/runs/*${EXEC:-}/proof*.json; запусти gate-fault-catalog-exec)"
elif ! _proof_out="$(python3 - "$proof" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
res = d.get("results") or []
if not d.get("ok"):
    print("gate-evidence-authentic: FAIL — proof.ok=false", file=sys.stderr); sys.exit(1)
if len(res) < 10:
    print(f"gate-evidence-authentic: FAIL — proof покрывает лишь {len(res)} детекторов (<10)", file=sys.stderr); sys.exit(1)
# A justified `na` (verdict in fault-verdicts.json) is reported by
# fault-catalog-check as status=skipped_na without exit. It is NOT a failed
# detector: the item is out of scope and the justification is mandatory.
# Treat only such justified skips as non-failing; an unjustified skip is an
# error (fail-closed). This mirrors gate-fault-catalog-exec, which already
# accepts the same proof.
def _ok(r):
    r = r or {}
    if r.get("status") == "skipped_na":
        return bool(str(r.get("justification") or "").strip())
    return r.get("status") == "ok" and r.get("exit") in (0,)
bad = [(r or {}).get("id") for r in res if not _ok(r)]
if bad:
    print(f"gate-evidence-authentic: FAIL — не все детекторы ok/exit0 (или justified na): {bad}", file=sys.stderr); sys.exit(1)
print(f"gate-evidence-authentic: proof OK ({len(res)} детекторов; ok/exit0 + justified na)")
PY
)"; then
  echo "$_proof_out" >&2
  record "proof детекторов: проверка не прошла (подробности выше)"
else
  echo "$_proof_out"
fi

if [ "${#FAILS[@]}" -gt 0 ]; then
  echo "gate-evidence-authentic: FAIL — ${#FAILS[@]} проверок не прошло (полный список выше)" >&2
  exit 1
fi
echo "gate-evidence-authentic: OK"
