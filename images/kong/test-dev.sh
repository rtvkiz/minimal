#!/bin/bash
# Smoke test for minimal-kong-dev.
# Same functional checks as prod, PLUS: bash/curl/jq are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kong version..."
v=$(docker run --rm --entrypoint /usr/local/bin/kong "$IMAGE" version 2>&1)
echo "$v" | grep -qiE '[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected version output: $v"; exit 1; }

echo "Testing kong starts DB-less and admin API answers over curl (offline)..."
cid=$(docker run -d -p 127.0.0.1:0:8001 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker exec "$cid" /usr/local/bin/kong health >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: kong did not report healthy"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

admin=$(docker exec "$cid" curl -sf http://127.0.0.1:8001/ 2>&1)
echo "$admin" | grep -qi 'version' || { echo "FAIL: admin API did not return version info: $admin"; exit 1; }

echo "Verifying bash present (dev only)..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" 2>&1 | grep -q x \
  || { echo "FAIL: expected bash in dev variant"; exit 1; }

echo "All kong-dev tests passed!"
