#!/bin/bash
# Smoke test for minimal-chartmuseum (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing chartmuseum version..."
ver=$(docker run --rm "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'ChartMuseum version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }
# Default env is local storage under /charts (owned by nonroot): serve an empty repo index.

echo "Testing chartmuseum serves /index.yaml (offline)..."
cid=$(docker run -d -p 18080:8080 "$IMAGE" )
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:18080/index.yaml >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: chartmuseum did not serve /index.yaml"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
body=$(curl -fsS --max-time 5 http://127.0.0.1:18080/index.yaml)
echo "$body" | grep -qE '^apiVersion: v1' \
  || { echo "FAIL: repository index.yaml missing from response"; exit 1; }
echo "✓ repository index.yaml"
health=$(curl -fsS --max-time 5 http://127.0.0.1:18080/health)
echo "$health" | grep -q '"healthy":true' || { echo "FAIL: /health not healthy: $health"; exit 1; }
echo "✓ /health reports healthy"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All chartmuseum tests passed!"
