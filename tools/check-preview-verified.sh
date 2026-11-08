#!/usr/bin/env bash
# gate-e2e-preview (s20c) — ВЕРИФИКАЦИЯ прогона E2E на арендованном стенде.
# Контейнер-безопасно (только HTTP + python; браузер НЕ нужен): сам прогон делает
# агент на docker-хосте (tools/run-stand-e2e.sh), здесь проверяем его результат:
#   1) есть аренда стенда и стенд здоров (healthz 200);
#   2) scenario-evidence.json — на каждый сценарий status=pass + скриншот
#      (fallback из execution root: ORC пересоздаёт eval-worktree перед гейтами);
#   3) preview-verdict.json — result=pass/status=verified и ВСЕ provenance-поля
#      (execution_id, evaluated_sha, stand, stand_image_digest, gate_bundle_digest,
#      artifact_digest, url, checked_at) совпадают с preview-deploy.json,
#      /healthz и (если есть) execution verification manifest. `ref` один
#      недостаточен: docker tag old new его подделывает.
# Любой провал → fail-close.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В pinned gate-bundle DIR=/opt/gate-tools/tools, а оцениваемое дерево — eval-root.
# Без ORC_GATE_ROOT проверяются файлы bundle (нет preview-verdict/scenarios/
# screenshots, ui_surface не git) — ложный FAIL (F199 s20c).
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
# Per-run артефакты живут в EXECUTION ROOT (.orc-eval/<E>/), а не в одноразовом
# commit-subdir, который ORC пересоздаёт перед гейтами (fallback — $ROOT).
exec_root() { case "$ROOT" in */.orc-eval/*/*) printf '%s' "${ROOT%/*}" ;; *) printf '%s' "$ROOT" ;; esac; }
# idea_file <relname> — артефакт ТЕКУЩЕЙ фичи (детерминированно; не «первый по glob»).
idea_file() { python3 "$DIR/_feature_dir.py" --root "$ROOT" --name "$1" 2>/dev/null; }
exec_id="${1:-${EXECUTION_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

fail() { echo "gate-e2e-preview: FAIL — $1" >&2; exit 1; }
# F12 (E6513): запрет правки гейтов/тулинга в ветке прогона.
bash "$DIR/check-tools-untouched.sh" || exit 1

# PASS-NA (E7141/F193): инкремент без изменений UI-поверхности → E2E-превью неприменимо.
# Правило симметрично gate-graph-actualized. Fail-closed: не смогли определить — работаем строго.
# F199: база — execution base_sha (как в gate-tools-untouched/l2), иначе
# устаревший origin/main в eval-worktree даёт обратный diff и UI-поверхность
# «появляется» у backend-only фичи. Fallback — маркер ORC в project root.
if [ -z "${ORC_BASE_SHA:-}" ] && [ -s "$ROOT/.orc-eval-base-sha" ]; then
  ORC_BASE_SHA="$(tr -d '\r\n' < "$ROOT/.orc-eval-base-sha" 2>/dev/null || true)"
fi
if [ -z "${ORC_BASE_SHA:-}" ]; then
  _d="$ROOT"
  while [ "$_d" != "/" ] && [ -n "$_d" ]; do
    if [ -s "$_d/.orc-base-sha" ]; then ORC_BASE_SHA="$(tr -d '\r\n' < "$_d/.orc-base-sha")"; break; fi
    _d="$(dirname "$_d")"
  done
fi
_ui_base="${UI_SURFACE_BASE:-${ORC_BASE_SHA:-origin/main}}"
_ui_rc=0; _ui_reason="$(python3 "$DIR/ui_surface.py" --root "$ROOT" --base "$_ui_base" --print-reason 2>/dev/null)" || _ui_rc=$?
if [ "$_ui_rc" = "1" ]; then
  echo "gate-e2e-preview: PASS-NA — инкремент без изменений UI-поверхности (${_ui_reason:-нет изменённых UI-файлов})"
  exit 0
fi

# F-05: пустой ref в вердикте — fail-close (иначе сверки ref↔HEAD↔deploy пропускаются).
_pv_path="$ROOT/preview-verdict.json"; [ -f "$_pv_path" ] || _pv_path="$(exec_root)/preview-verdict.json"
ref_val="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("ref",""))
except Exception: print("")' "$_pv_path" 2>/dev/null || true)"
[ -n "$ref_val" ] || fail "preview-verdict.json без ref (нельзя сопоставить E2E с выкаченным кодом)"

get() { # стенд по TLS с self-signed сертификатом → проверяем без валидации CA (идентичность
# подтверждается отдельно: /healthz.build_ref == выкаченный ref). -L: корень стенда
# отдаёт 301 → /ui/ (nginx.stand.conf.tmpl) — без следования bundle не находился (F-A-S20C-01).
  if command -v curl >/dev/null 2>&1; then curl -kfsS -L -m 12 -H "Authorization: Bearer $tok" "$1"; else wget -qO- --header="Authorization: Bearer $tok" "$1"; fi; }
code() { # стенд по TLS с self-signed сертификатом → проверяем без валидации CA (идентичность
# подтверждается отдельно: /healthz.build_ref == выкаченный ref)
  if command -v curl >/dev/null 2>&1; then curl -k -o /dev/null -s -m 12 -w '%{http_code}' "$1"; else wget --no-check-certificate -qO /dev/null -S "$1" 2>&1 | awk '/HTTP\//{c=$2} END{print c}'; fi; }

# 1) аренда + здоровье стенда
url=""
if [ -n "$exec_id" ] && [ -n "$tok" ]; then
  url="$(get "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null \
    | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_url",""))' 2>/dev/null || true)"
fi
# Fallback (F-A-S20C-01): если привилегированная аренда недоступна — стенд из preview-deploy.json.
_pd_path="$ROOT/preview-deploy.json"; [ -f "$_pd_path" ] || _pd_path="$(exec_root)/preview-deploy.json"
if [ -z "$url" ] && [ -f "$_pd_path" ]; then
  url="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("url","") or "")' "$_pd_path" 2>/dev/null || true)"
fi
[ -n "$url" ] || fail "нет арендованного стенда (execution=${exec_id:-?})"
[ "$(code "${url%/}/healthz")" = "200" ] || fail "стенд нездоров (healthz≠200)"
# ИДЕНТИЧНОСТЬ стенда (E8141): 200 от чужого сервиса не доказывает ничего — требуем
# build_ref (ref выкаченного образа) и сверяем его с preview-deploy.json/HEAD ниже.
hz="$(get "${url%/}/healthz" 2>/dev/null || true)"
stand_build_ref="$(printf '%s' "$hz" | python3 -c 'import sys,json
try: print((json.load(sys.stdin) or {}).get("build_ref","") or "")
except Exception: print("")' 2>/dev/null || true)"
[ -n "$stand_build_ref" ] || fail "стенд ${url} не подтверждает билд: в /healthz нет build_ref (обнови образ стенда; иначе нельзя убедиться, что E2E шёл на этом стенде)"

# 2) scenario-evidence против scenarios
sc="$(idea_file scenarios.json)"
[ -n "$sc" ] || fail "нет scenarios.json"
ev="$(idea_file scenario-evidence.json)"
# F-RUN-02b: per-run evidence живёт в execution root и переживает пересоздание
# eval-worktree (ORC всегда пересоздаёт worktree перед гейтами). Если в свежем
# worktree evidence нет — строго переносим его + скриншоты из execution root.
# Не расширяет allowlist приёмки: только точный feature_dir, только referenced
# screenshots, sha256/l stat/tracked проверяются helper'ом.
if [ -z "$ev" ]; then
  _er="$(exec_root)"
  _feat=""
  if [ -n "${ORC_FEATURE_DIR:-}" ]; then
    case "$ORC_FEATURE_DIR" in
      /*) ;;
      *) _feat="$ORC_FEATURE_DIR" ;;
    esac
  fi
  if [ -z "$_feat" ]; then
    _feat="$(python3 -c 'import os,sys;print(os.path.relpath(os.path.dirname(sys.argv[1]), sys.argv[2]))' "$sc" "$ROOT" 2>/dev/null || true)"
  fi
  case "$_feat" in
    ""|.|..|../*|/*) _feat="" ;;
  esac
  if [ -n "$_feat" ] && [ "$_er" != "$ROOT" ] && [ -f "$_er/$_feat/scenario-evidence.json" ]; then
    python3 "$DIR/preview_evidence_fallback.py" \
      --worktree-root "$ROOT" --execution-root "$_er" \
      --feature-dir "$_feat" --execution-id "${exec_id:-}" \
      || fail "per-run evidence из execution root не прошёл строгую проверку"
    ev="$(idea_file scenario-evidence.json)"
  fi
fi
[ -n "$ev" ] || fail "нет scenario-evidence.json (E2E не прогнан)"
scen_out="$(mktemp)"; ( cd "$ROOT" && python3 "$DIR/check-scenario-coverage.py" --brief "$sc" --evidence "$ev" ) >"$scen_out" 2>&1 \
  || { sed 's/^/  /' "$scen_out"; rm -f "$scen_out"; fail "scenario-coverage (evidence) не пройден"; }; rm -f "$scen_out"

# 3) preview-verdict: verified + target==стенд + evaluated_sha/digest/bundle
#    совпадают с execution deploy-манифестом и /healthz. Одного ref мало:
#    `docker tag old new` подделывает build_ref, но не image_digest.
pv="$ROOT/preview-verdict.json"; [ -f "$pv" ] || pv="$(exec_root)/preview-verdict.json"
[ -f "$pv" ] || fail "нет preview-verdict.json (E2E не прогнан)"
dpv="$ROOT/preview-deploy.json"; [ -f "$dpv" ] || dpv="$(exec_root)/preview-deploy.json"
[ -f "$dpv" ] || fail "нет preview-deploy.json — нельзя привязать verdict к evaluated_sha/stand_image_digest"
head="$(git -C "$ROOT" rev-parse --short HEAD)"
manifest_path="${ORC_EXECUTION_MANIFEST:-$ROOT/verification-manifest.json}"
[ -f "$manifest_path" ] || manifest_path=""
python3 - "$pv" "$dpv" "$hz" "$url" "${exec_id:-}" "$manifest_path" <<'PY' || exit 1
import sys, json, re, os
pv_p, dep_p, hz_raw, url, exec_id, manifest_p = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].rstrip('/'), sys.argv[5], sys.argv[6])
def fail(m):
    print(f"gate-e2e-preview: FAIL — {m}", file=sys.stderr); sys.exit(1)
def load(p):
    try:
        d = json.load(open(p, encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except Exception as e:
        fail(f"{p}: {e}")
def sha256_ok(s):
    return isinstance(s, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", s or "") is not None
def full_sha(s):
    return isinstance(s, str) and re.fullmatch(r"[0-9a-f]{40}", s or "") is not None

d, dep = load(pv_p), load(dep_p)
try:
    hz = json.loads(hz_raw)
    if not isinstance(hz, dict): hz = {}
except Exception:
    hz = {}

res = (d.get('result') or '').lower()
if res != 'pass':
    fail(f"preview-verdict.result={res!r} (нужно 'pass')")
st = (d.get('status') or '').lower()
if st != 'verified':
    fail(f"preview-verdict.status={st!r} (нужно 'verified')")
tgt = (d.get('target') or '').rstrip('/')
if tgt != url:
    fail(f"preview-verdict.target={tgt!r} ≠ стенд {url!r}")
vurl = (d.get('url') or '').rstrip('/')
if vurl != url:
    fail(f"preview-verdict.url={vurl!r} ≠ стенд {url!r}")

# execution identity
exec_decl = str(d.get('execution_id') or d.get('execution') or '')
dep_exec = str(dep.get('execution_id') or '')
if exec_id and exec_decl and exec_decl != exec_id:
    fail(f"preview-verdict.execution_id={exec_decl!r} ≠ {exec_id!r}")
if dep_exec and exec_decl and dep_exec != exec_decl:
    fail(f"preview-verdict.execution_id={exec_decl!r} ≠ preview-deploy.execution_id={dep_exec!r}")
if not exec_decl:
    fail("preview-verdict без execution_id")

# evaluated SHA: verdict == deploy == /healthz.commit
ev = str(d.get('evaluated_sha') or '')
dep_ev = str(dep.get('evaluated_sha') or dep.get('commit') or '')
if not full_sha(ev):
    fail(f"preview-verdict.evaluated_sha={ev!r} не 40hex")
if dep_ev != ev:
    fail(f"preview-verdict.evaluated_sha={ev} ≠ preview-deploy={dep_ev}")
hz_commit = str(hz.get('commit') or '')
if not hz_commit:
    fail("стенд не подтверждает commit: в /healthz нет commit")
if hz_commit != ev:
    fail(f"стенд /healthz.commit={hz_commit} ≠ evaluated_sha={ev}")
ref = str(d.get('ref') or dep.get('ref') or '')
if ref and not (ev == ref or ev.startswith(ref)):
    fail(f"preview-verdict.ref={ref} не является префиксом evaluated_sha={ev}")

# stand + image digest
stand = str(d.get('stand') or '')
dep_stand = str(dep.get('stand') or '')
if not stand:
    fail("preview-verdict без stand")
if dep_stand and stand != dep_stand:
    fail(f"preview-verdict.stand={stand!r} ≠ preview-deploy.stand={dep_stand!r}")
vd = str(d.get('stand_image_digest') or '')
dd = str(dep.get('stand_image_digest') or '')
hd = str(hz.get('image_digest') or '')
if not sha256_ok(vd):
    fail(f"preview-verdict.stand_image_digest={vd!r} не sha256")
if not sha256_ok(dd):
    fail(f"preview-deploy.stand_image_digest={dd!r} не sha256 (docker tag spoof?)")
if not sha256_ok(hd):
    fail(f"/healthz.image_digest={hd!r} не sha256 (стенд не подтверждает образ)")
if vd != dd:
    fail(f"preview-verdict.stand_image_digest={vd} ≠ preview-deploy={dd} (чужой образ)")
if vd != hd:
    fail(f"preview-verdict.stand_image_digest={vd} ≠ /healthz.image_digest={hd} (docker tag spoof?)")

# build inputs
vh = str(d.get('build_args_hash') or '')
dh = str(dep.get('build_args_hash') or '')
hh = str(hz.get('build_args_hash') or '')
if dh and vh and dh != vh:
    fail(f"preview-verdict.build_args_hash={vh} ≠ preview-deploy={dh}")
if (vh or dh) and not hh:
    fail("стенд не подтверждает build_args_hash: в /healthz нет build_args_hash")
if hh and (vh or dh) and hh != (vh or dh):
    fail(f"/healthz.build_args_hash={hh} ≠ verdict/deploy={vh or dh}")

# gate bundle digest (may be empty for non-ORC projects; when set all must agree)
vg = str(d.get('gate_bundle_digest') or '')
dg = str(dep.get('gate_bundle_digest') or '')
hg = str(hz.get('gate_bundle_digest') or '')
if dg and vg and dg != vg:
    fail(f"preview-verdict.gate_bundle_digest={vg} ≠ preview-deploy={dg}")
if (vg or dg) and not hg:
    fail("стенд не подтверждает gate_bundle_digest: в /healthz нет gate_bundle_digest")
if hg and (vg or dg) and hg != (vg or dg):
    fail(f"/healthz.gate_bundle_digest={hg} ≠ verdict/deploy={vg or dg}")

# artifact evidence: artifact_digest is the sha256 of the evidence manifest.
# The producer may write it with or without the "sha256:" prefix, while
# evidence_manifest_sha256 is the bare hex digest. Normalize both sides before
# the comparison; a missing/invalid digest is still fail-close.
def sha256_hex_ok(s):
    return isinstance(s, str) and re.fullmatch(r"[0-9a-f]{64}", s or "") is not None
def strip_sha256(s):
    s = str(s or "").strip()
    return s[len("sha256:"):] if s.startswith("sha256:") else s
ad_raw = str(d.get('artifact_digest') or '')
em_raw = str(d.get('evidence_manifest_sha256') or '')
ad = strip_sha256(ad_raw)
em = strip_sha256(em_raw)
if not sha256_hex_ok(ad):
    fail(f"preview-verdict.artifact_digest={ad_raw!r} не sha256 (ожидается sha256:<64hex> или <64hex>)")
if not sha256_hex_ok(em):
    fail(f"preview-verdict.evidence_manifest_sha256={em_raw!r} не sha256 (ожидается sha256:<64hex> или <64hex>)")
if ad != em:
    fail(f"preview-verdict.artifact_digest={ad_raw} ≠ evidence_manifest_sha256={em_raw}")
if not str(d.get('checked_at') or d.get('ts') or ''):
    fail("preview-verdict без checked_at")

# Optional: the immutable execution verification manifest (ADR-3 W3.1) is the
# authoritative evaluated_sha/gate_bundle_digest source when available.
if manifest_p and os.path.isfile(manifest_p):
    vm = load(manifest_p)
    if str(vm.get('execution_id') or '') and vm.get('execution_id') != exec_decl:
        fail(f"preview-verdict.execution_id={exec_decl} ≠ execution manifest={vm.get('execution_id')}")
    if str(vm.get('evaluated_sha') or '') and vm.get('evaluated_sha') != ev:
        fail(f"preview-verdict.evaluated_sha={ev} ≠ execution manifest={vm.get('evaluated_sha')}")
    mg = str(vm.get('gate_bundle_digest') or '')
    if mg and (vg or dg) and mg != (vg or dg):
        fail(f"execution manifest.gate_bundle_digest={mg} ≠ verdict/deploy={vg or dg}")
    ms = str(vm.get('stand_image_digest') or '')
    if ms and ms != vd:
        fail(f"execution manifest.stand_image_digest={ms} ≠ verdict={vd}")

# build_ref identity (legacy + image build provenance)
build_ref = str(hz.get('build_ref') or '')
if not build_ref:
    fail("стенд не подтверждает билд: в /healthz нет build_ref")
dep_ref = str(dep.get('ref') or dep.get('build_ref') or '')
if dep_ref and build_ref != dep_ref and not ev.startswith(build_ref):
    fail(f"стенд /healthz.build_ref={build_ref} ≠ выкаченный ref={dep_ref}")
PY
ref="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("ref",""))' "$pv" 2>/dev/null)"
if [ -n "$ref" ] && [ "$ref" != "$head" ]; then
  # Test-only пути не меняют собранный bundle: новые E2E/юнит-оракулы,
  # снапшоты и конфиги тест-раннеров после деплоя не должны инвалидировать
  # preview-verdict.ref (иначе приходится пере-деплоить test-only коммит).
  changed="$(git -C "$ROOT" -c core.quotepath=false diff --name-only "${ref}..HEAD" 2>/dev/null | grep -vE '\.md$|^doc/|^docs/|^preview-deploy\.json$|^preview-verdict\.json$|^\.e2e-artifacts/|^data/audit/runs/|tsbuildinfo|^\.gitignore$|^\.gitattributes$|^frontend/e2e/|^frontend/(vitest|playwright)\.config\.|^frontend/.*/__tests__/|^frontend/.*\.(spec|test)\.(ts|tsx)$|\.snap$' || true)"
  [ -z "$changed" ] || fail "preview-verdict.ref=$ref устарел — после него изменён код: $(echo "$changed" | tr '\n' ' ')"
fi
# F8: verdict.ref обязан совпадать с фактически выкаченным ref (preview-deploy.json).
dpv="$ROOT/preview-deploy.json"; [ -f "$dpv" ] || dpv="$(exec_root)/preview-deploy.json"
if [ -f "$dpv" ]; then
  dep="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("ref",""))' "$dpv" 2>/dev/null)"
  if [ -n "$dep" ] && [ -n "$ref" ] && [ "$ref" != "$dep" ]; then
    fail "preview-verdict.ref=$ref ≠ preview-deploy.ref=$dep (E2E-вердикт не для выкаченного кода)"
  fi
  if [ -n "$dep" ] && [ "$stand_build_ref" != "$dep" ]; then
    fail "стенд отдаёт build_ref=$stand_build_ref, а выкачен ref=$dep — E2E шёл не на стенде этого прогона"
  fi
fi
# сверка пробы с БИЛДОМ (p.5): проба обязана быть снята с выкаченного бандла, а не с
# устаревшего precache/service-worker (аномалия A1 в F003: android отдавал бандл пре-abe20da).
bund="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("bundle",""))' "$pv" 2>/dev/null)"
index_html="$(get "${url%/}/" 2>/dev/null || true)"
# Bundle-имя задаёт сборка (Vite: index-*.js, другие шаблоны: main-*.js).
# Проверяем точное имя из preview-verdict.json, а не жёсткий index-паттерн;
# иначе валидный стенд ложно падает на assets/main-*.js.
if [ -n "$bund" ]; then
  if printf '%s' "$index_html" | grep -qF "$bund"; then
    served="$bund"
  else
    served="$(printf '%s' "$index_html" | grep -oE 'assets/[A-Za-z0-9._-]+\.js' | head -1 || true)"
    [ -n "$served" ] || fail "в index.html стенда не найден JS-бандл assets/*.js"
    fail "стенд отдаёт '$served', а E2E-вердикт снят для '$bund' (другой билд / stale precache)"
  fi
else
  # Non-hashed static app (server-rendered HTML + /app.js): there is no build
  # asset name to pin, so an empty bundle is legitimate. This is NOT a bypass:
  # a stand that does expose a hashed build asset still requires a bundle, and
  # the fallback script must be same-origin and served successfully.
  hashed="$(printf '%s' "$index_html" | grep -oE 'assets/[A-Za-z0-9._-]+\.js' | head -1 || true)"
  [ -z "$hashed" ] || fail "стенд отдаёт хешированный бандл '$hashed', а preview-verdict.json без bundle (перезапусти run-stand-e2e)"
  served="$(printf '%s' "$index_html" | grep -oE 'src="[^"]+\.js[^"]*"' | head -1 | sed -E 's/^src="([^"]+)".*/\1/' || true)"
  [ -n "$served" ] || fail "в index.html стенда не найден JS-бандл и preview-verdict.json без bundle"
  case "$served" in
    //*|*://*) fail "JS-бандл стенда не same-origin: $served" ;;
    /*) ;;
    *) served="/$served" ;;
  esac
  [ "$(code "${url%/}${served}")" = "200" ] || fail "стенд не отдаёт JS-бандл '$served' (HTTP != 200)"
fi
echo "gate-e2e-preview: OK — E2E на ${url} (screenshots+evidence, ref=${ref:-$head}, bundle=$served)"
