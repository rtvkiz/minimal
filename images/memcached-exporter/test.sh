#!/bin/bash
# Smoke test for minimal-memcached-exporter (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing memcached-exporter version..."
ver=$(docker run --rm --entrypoint /usr/bin/memcached_exporter "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'memcached_exporter, version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }
# Points at an unreachable memcached: the exporter still serves and reports memcached_up 0.

echo "Testing memcached-exporter serves /metrics (offline)..."
cid=$(docker run -d -p 19150:9150 "$IMAGE" --memcached.address=127.0.0.1:1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:19150/metrics >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: memcached-exporter did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
body=$(curl -fsS --max-time 5 http://127.0.0.1:19150/metrics)
echo "$body" | grep -qE 'memcached_exporter_build_info' \
  || { echo "FAIL: memcached_exporter_build_info metric missing from response"; exit 1; }
echo "✓ memcached_exporter_build_info metric"
echo "$body" | grep -qE '^memcached_up 0' \
  || { echo "FAIL: memcached_up 0 for the unreachable target missing from response"; exit 1; }
echo "✓ memcached_up 0 for the unreachable target"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All memcached-exporter tests passed!"
