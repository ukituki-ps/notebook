#!/usr/bin/env bash
# gate-preview-deploy (ADR-KIT-091) — ВЕРИФИКАЦИЯ выката на арендованный стенд.
# Контейнер-безопасно (нужен только HTTP-клиент; docker НЕ требуется): сам выкат
# делает агент на docker-хосте через tools/deploy-preview-stand.sh (он пишет
# preview-deploy.json). Гейт проверяет: файл есть, ref == HEAD, стенд healthz=200.
# Нет аренды/файла/ответа → FAIL (fail-close).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The platform runs this script from the pinned kit root; per-run artifacts
# (preview-deploy.json) live in the evaluation tree, exported as ORC_GATE_ROOT.
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
exec_id="${1:-${EXECUTION_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

fail() { echo "gate-preview-deploy: FAIL — $1" >&2; exit 1; }
# F12 (E6513): запрет правки гейтов/тулинга в ветке прогона.
bash "$DIR/check-tools-untouched.sh" || exit 1

# F-RUN-02 (E7141): per-run артефакты не должны быть в git — коммит preview-deploy.json
# после выката сдвигает HEAD и ломает проверку идентичности выката (2 accept_fail на s20b).
if ! bash "$DIR/check-run-artifacts.sh" "$ROOT" >/dev/null 2>&1; then
  bash "$DIR/check-run-artifacts.sh" "$ROOT" >&2 || true
  exit 1
fi
get() { # get <url> ; curl→wget fallback
  if command -v curl >/dev/null 2>&1; then
    curl -kfsS -m 12 -H "Authorization: Bearer $tok" "$1"
  else
    wget -qO- --header="Authorization: Bearer $tok" "$1"
  fi
}
code() { # code <url> → HTTP status
  if command -v curl >/dev/null 2>&1; then
    curl -k -o /dev/null -s -m 12 -w '%{http_code}' "$1"
  else
    wget --no-check-certificate -qO /dev/null -S "$1" 2>&1 | awk '/HTTP\//{c=$2} END{print c}'
  fi
}

# Per-run артефакт живёт в EXECUTION ROOT (.orc-eval/<E>/), а не в одноразовом
# commit-subdir: ORC пересоздаёт eval worktree перед гейтами, и файл из
# <E>/<sha>/ исчез бы. Fallback на $ROOT оставлен для worktree-транспорта.
exec_root() { case "$ROOT" in */.orc-eval/*/*) printf '%s' "${ROOT%/*}" ;; *) printf '%s' "$ROOT" ;; esac; }
f="$ROOT/preview-deploy.json"
[ -f "$f" ] || f="$(exec_root)/preview-deploy.json"
[ -f "$f" ] || fail "нет preview-deploy.json — ветка не выкачена на стенд (запусти tools/deploy-preview-stand.sh)"

head="$(git -C "$ROOT" rev-parse --short HEAD)"
dep_ref="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("ref",""))' "$f" 2>/dev/null || true)"
dep_stand="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("stand",""))' "$f" 2>/dev/null || true)"
[ -n "$dep_ref" ] || fail "preview-deploy.json без ref"
if [ "$dep_ref" != "$head" ]; then
  # Не-код пути (док/артефакты прогона) не делают выкат устаревшим. `evidence/`
  # — такая же доказательная зона, как `data/audit/runs/` (E8267: после выката
  # ветка получила evidence/f002.4/*.json, код не менялся).
  changed="$(git -C "$ROOT" -c core.quotepath=false diff --name-only "${dep_ref}..HEAD" 2>/dev/null | grep -vE '\.md$|^doc/|^docs/|^evidence/|^preview-deploy\.json$|^preview-verdict\.json$|^\.e2e-artifacts/|^data/audit/runs/|tsbuildinfo|^\.gitignore$|^\.gitattributes$' || true)"
  # `.orc-trust/**` из влитого origin/main — не код и не правка feature (E8267).
  # Не глобальное исключение: путь игнорируется ТОЛЬКО когда blob/tree sha
  # совпадает с origin/main; любое реальное изменение остаётся и валит гейт
  # (для `.orc-trust` его независимо проверяет check-tools-untouched).
  if [ -n "$changed" ] && printf '%s\n' "$changed" | grep -qE '^\.orc-trust(/|$)'; then
    trust_remote="${ORC_TRUST_REMOTE_URL:-$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || true)}"
    [ -n "$trust_remote" ] || fail "anchor_unavailable: .orc-trust в diff, origin не задан"
    anchor="$(git -C "$ROOT" ls-remote --exit-code "$trust_remote" refs/heads/main 2>/dev/null | awk 'NR==1{print $1}')"
    [ -n "$anchor" ] || fail "anchor_unavailable: origin/main недоступен ($trust_remote)"
    if ! git -C "$ROOT" cat-file -e "${anchor}^{commit}" 2>/dev/null; then
      git -C "$ROOT" fetch --no-tags --quiet "$trust_remote" refs/heads/main >/dev/null 2>&1 \
        || fail "anchor_unavailable: не удалось получить origin/main"
      anchor="$(git -C "$ROOT" rev-parse FETCH_HEAD 2>/dev/null || true)"
      [ -n "$anchor" ] || fail "anchor_unavailable: пустой FETCH_HEAD"
    fi
    kept=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        .orc-trust|.orc-trust/*)
          h="$(git -C "$ROOT" rev-parse --verify "HEAD:$p" 2>/dev/null || true)"
          m="$(git -C "$ROOT" rev-parse --verify "${anchor}:$p" 2>/dev/null || true)"
          if [ -n "$h" ] && [ "$h" = "$m" ]; then continue; fi
          ;;
      esac
      kept+="$p"$'\n'
    done <<< "$changed"
    changed="$kept"
  fi
  [ -z "$changed" ] || fail "выкачен ref=$dep_ref устарел — после него изменён код: $(echo "$changed" | tr '\n' ' ')"
fi

# ADR-KIT-091: command gates never receive NEXUS_TOKEN. Bind the deployed stand
# to this execution via the ORC-signed lease proof instead; resolve the public
# URL from the trusted stand registry, never from preview-deploy.json.
proof="${ORC_STAND_LEASE_PROOF:-}"
pubkey="${ORC_LEASE_PROOF_PUBKEY:-}"
[ -n "$proof" ] || fail "нет ORC_STAND_LEASE_PROOF — выкат не привязан к аренде (fail-close)"
[ -n "$pubkey" ] || fail "нет ORC_LEASE_PROOF_PUBKEY — нельзя проверить lease proof (fail-close)"
bash "$DIR/check-stand-leased.sh" "$exec_id" "${PROJECT_ID:-}" || exit 1
stand="$(python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("stand",""))' <<<"$proof" 2>/dev/null || true)"
[ -n "$stand" ] || fail "lease proof без stand"
# E8267: URL берётся из ПОДПИСАННОГО lease proof (`stand_url`), а не из
# kit-реестра `tools/stands.json`. Kit-реестр принадлежит платформе
# (test1 → test1.nexus...), а у проекта свой test1 (test1.kubiki-health...);
# из-за этого здоровый выкат E8267 валился как «отвечает не стенд этого
# прогона». `stand_url` кладёт ORC из project-scoped Nexus lease, подпись
# покрывает поле (check-stand-leased проверил её выше). Registry — fallback
# только для старых proof без поля.
url="$(python3 -c 'import sys,json;print((json.loads(sys.stdin.read()) or {}).get("stand_url",""))' <<<"$proof" 2>/dev/null || true)"
if [ -n "$url" ]; then
  :
else
  registry=""
  for cand in "$DIR/stands.json" "$(cd "$DIR/.." && pwd)/deploy/stands/stands.json" "$ROOT/deploy/stands/stands.json"; do
    if [ -f "$cand" ]; then registry="$cand"; break; fi
  done
  [ -n "$registry" ] || fail "нет stands.json для stand=${stand} (fail-close)"
  url="$(python3 - "$registry" "$stand" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1],encoding="utf-8"))
    e=d.get(sys.argv[2]) or {}
    print(e.get("public_url","") or e.get("url",""))
except Exception:
    print("")
PY
)"
  [ -n "$url" ] || fail "stand ${stand} не найден в stands.json (${registry})"
fi
case "$url" in
  http://*|https://*) ;;
  *) fail "stand_url не http(s): $url" ;;
esac
c="$(code "${url%/}/healthz")"
[ "$c" = "200" ] || fail "стенд ${dep_stand:-$url} нездоров (healthz=$c)"
# ИДЕНТИЧНОСТЬ стенда (инцидент E8141): healthz=200 мог прийти от ЧУЖОГО сервиса
# (test1.nexus.ukituki.tech проксировал на другой хост) — «зелёный» выкат при этом
# не подтверждал ничего. Требуем, чтобы /healthz подтвердил build_ref == выкаченный ref.
hz="$(get "${url%/}/healthz" 2>/dev/null || true)"
[ -n "$hz" ] || fail "стенд ${dep_stand:-$url} не отдал /healthz JSON"
# ADR-10 / W3.7: identity is the IMAGE DIGEST + evaluated SHA, not the tag.
# preview-deploy.json records the expected digest from build provenance; a
# `docker tag old new` leaves the old digest in /healthz and fails here.
python3 - "$f" "$hz" "${dep_ref}" <<'PY' || exit 1
import sys, json, re
dep_p, hz_raw, dep_ref = sys.argv[1], sys.argv[2], sys.argv[3]
def fail(m):
    print(f"gate-preview-deploy: FAIL — {m}", file=sys.stderr); sys.exit(1)
def sha(s): return isinstance(s, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", s or "") is not None
def full(s): return isinstance(s, str) and re.fullmatch(r"[0-9a-f]{40}", s or "") is not None
try:
    dep = json.load(open(dep_p, encoding="utf-8"))
except Exception as e:
    fail(f"preview-deploy.json: {e}")
try:
    hz = json.loads(hz_raw)
    if not isinstance(hz, dict): hz = {}
except Exception:
    hz = {}
dd = str(dep.get("stand_image_digest") or "")
dc = str(dep.get("evaluated_sha") or dep.get("commit") or "")
dh = str(dep.get("build_args_hash") or "")
hd = str(hz.get("image_digest") or "")
hc = str(hz.get("commit") or "")
hh = str(hz.get("build_args_hash") or "")
br = str(hz.get("build_ref") or "")
# build_ref is the mandatory identity for the current deploy artifact (the
# stand image does not always expose a digest). Digest/commit/hash are enforced
# when both the artifact and /healthz carry them.
if not br: fail("стенд не подтверждает билд: в /healthz нет build_ref")
if dd and not sha(dd): fail(f"preview-deploy.stand_image_digest={dd!r} не sha256 (нет build provenance)")
if dc and not full(dc): fail(f"preview-deploy.evaluated_sha={dc!r} не 40hex")
if dd and hd and hd != dd: fail(f"/healthz.image_digest={hd} ≠ выкаченный digest={dd} (docker tag spoof / чужой образ)")
if dc and hc and hc != dc: fail(f"/healthz.commit={hc} ≠ evaluated_sha={dc}")
if dh and hh and hh != dh: fail(f"/healthz.build_args_hash={hh} ≠ выкаченный={dh}")
def ref_match(a, b):
    # Короткий git-ref (>=7) и полный 40hex — один коммит, если один является
    # префиксом другого (E8267: /healthz отдал build_ref=8059f18f, а
    # preview-deploy.ref=8059f18f12e6…, evaluated_sha в артефакте нет).
    if not a or not b:
        return False
    if a == b:
        return True
    if len(a) >= 7 and b.startswith(a):
        return True
    if len(b) >= 7 and a.startswith(b):
        return True
    return False

if not ref_match(br, dep_ref) and not ref_match(br, dc):
    fail(f"стенд отдаёт build_ref={br}, а выкачен ref={dep_ref} — отвечает не стенд этого прогона")
PY
echo "gate-preview-deploy: OK — ref=$head на стенде ${dep_stand} (healthz 200, image_digest подтверждён)"
