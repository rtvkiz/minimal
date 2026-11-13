#!/bin/bash
# Smoke test for minimal-ghost-dev.
# Same boot check as prod, PLUS: bash, apk, npm and a C compiler.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing ghost version (expect $EXPECTED)..."
v=$(docker run --rm --network none --entrypoint /usr/bin/node "$IMAGE" -p "require('/usr/lib/ghost/package.json').version" 2>&1)
[ "$v" = "$EXPECTED" ] || { echo "FAIL: unexpected ghost version: $v"; exit 1; }

echo "Testing ghost boots and answers its admin API..."
vol="minimal-ghost-dev-smoke-$$"
docker volume create "$vol" >/dev/null
cid=$(docker run -d -e privacy__useUpdateCheck=false -e privacy__useGravatar=false \
        -v "$vol:/var/lib/ghost/content" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 90); do
  if docker exec "$cid" curl -sf http://127.0.0.1:2368/ghost/api/admin/site/ >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: ghost did not answer on :2368"; docker logs "$cid" 2>&1 | tail -40; exit 1; }

echo "Verifying bash, apk, npm and cc present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; npm --version; cc --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All ghost-dev tests passed!"
