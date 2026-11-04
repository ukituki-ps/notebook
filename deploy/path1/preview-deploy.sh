#!/usr/bin/env bash
# preview-deploy.sh <stand> <ref> — dev-only выкат notebook на арендованный стенд.
# Запускается platform-скриптом deploy-preview-stand.sh из app-репо (cwd=app root).
# Prod/test1 запрещены. Пишет build/deploy provenance в deploy/stands/.runtime/<stand>/.
set -euo pipefail

stand="${1:?usage: preview-deploy.sh <stand> <ref>}"
ref="${2:-HEAD}"
case "$stand" in
  test2) ;;
  *) echo "preview-deploy: dev-only: разрешён только test2 (got '$stand')" >&2; exit 2 ;;
esac
case "$ref" in
  *prod*) echo "preview-deploy: prod ref запрещён ($ref)" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
commit="$(git rev-parse "$ref")"
short="$(git rev-parse --short "$ref")"
img="notebook-stand:${stand}-${short}"
gate="${NEXUS_GATE_BUNDLE_DIGEST:-}"
args_hash="$(printf 'NEXUS_BUILD_SHA=%s\nNEXUS_BUILD_REF=%s\nNEXUS_GATE_BUNDLE_DIGEST=%s\n' \
  "$commit" "$short" "$gate" | sha256sum | awk '{print "sha256:"$1}')"
runtime="$ROOT/deploy/stands/.runtime/$stand"
mkdir -p "$runtime"

echo "preview-deploy: build $img (commit=$commit)"
docker build -f "$ROOT/deploy/Dockerfile" -t "$img" \
  --build-arg "NEXUS_BUILD_SHA=$commit" \
  --build-arg "NEXUS_BUILD_REF=$short" \
  --build-arg "NEXUS_BUILD_ARGS_HASH=$args_hash" \
  --build-arg "NEXUS_GATE_BUNDLE_DIGEST=$gate" \
  "$ROOT"
digest="$(docker inspect --format '{{.Id}}' "$img")"
[ -n "$digest" ] || { echo "preview-deploy: docker inspect failed for $img" >&2; exit 1; }
printf '{"schema":"orc.stand-build-provenance/v1","stand":"%s","image":"%s","image_digest":"%s","commit":"%s","build_ref":"%s","build_args_hash":"%s","gate_bundle_digest":"%s","built_at":"%s"}\n' \
  "$stand" "$img" "$digest" "$commit" "$short" "$args_hash" "$gate" "$(date -u +%FT%TZ)" \
  > "$runtime/build-provenance.json"

net="notebook-stand-${stand}-net"
app="notebook-stand-${stand}-app"
edge="notebook-stand-${stand}-edge"
# pr01's default Docker address pool is exhausted: always pin an explicit,
# free /24 for the stand network instead of relying on auto-allocation.
case "$stand" in
  test1) subnet="10.77.11.0/24" ;;
  test2) subnet="10.77.12.0/24" ;;
  *) echo "preview-deploy: no subnet mapping for stand '$stand'" >&2; exit 2 ;;
esac
if ! docker network inspect "$net" >/dev/null 2>&1; then
  docker network create --subnet "$subnet" "$net" >/dev/null
fi
docker rm -f "$edge" "$app" >/dev/null 2>&1 || true

docker run -d --name "$app" --network "$net" --restart unless-stopped \
  -e "NEXUS_BUILD_SHA=$commit" -e "NEXUS_BUILD_REF=$short" \
  -e "NEXUS_BUILD_ARGS_HASH=$args_hash" -e "NEXUS_GATE_BUNDLE_DIGEST=$gate" \
  -e "NEXUS_IMAGE_DIGEST=$digest" "$img" >/dev/null

cat > "$runtime/nginx.conf" <<CONF
server {
    listen 80;
    server_name $stand.nexus.ukituki.tech;
    client_max_body_size 10m;
    location = /nginx-health { access_log off; return 200 "ok\\n"; }
    location = /healthz {
        default_type application/json;
        return 200 '{"status":"ok","build_ref":"$short","commit":"$commit","image_digest":"$digest","build_args_hash":"$args_hash","gate_bundle_digest":"$gate"}';
    }
    location /api/ {
        proxy_pass http://$app:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    location / {
        proxy_pass http://$app:8080;
        proxy_set_header Host \$host;
    }
}
CONF
docker run -d --name "$edge" --network "$net" --restart unless-stopped \
  -p 9082:80 \
  -v "$runtime/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:alpine >/dev/null

ok=0
for _ in $(seq 1 60); do
  if curl -fsS -m 3 http://127.0.0.1:9082/healthz >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
[ "$ok" = "1" ] || { echo "preview-deploy: healthcheck FAIL (edge/app)" >&2; exit 1; }

printf '{"schema":"orc.stand-deploy-provenance/v1","stand":"%s","image":"%s","image_digest":"%s","commit":"%s","build_ref":"%s","build_args_hash":"%s","gate_bundle_digest":"%s","deployed_at":"%s"}\n' \
  "$stand" "$img" "$digest" "$commit" "$short" "$args_hash" "$gate" "$(date -u +%FT%TZ)" \
  > "$runtime/deploy-provenance.json"
echo "preview-deploy: GREEN $stand on $img (digest=$digest)"
