#!/bin/bash
# Smoke test for minimal-mongodb-exporter (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing mongodb-exporter version..."
ver=$(docker run --rm --entrypoint /usr/bin/mongodb_exporter "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'Version: v[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing the upstream /mongodb_exporter path..."
ver2=$(docker run --rm --entrypoint /mongodb_exporter "$IMAGE" --version 2>&1 || true)
[ "$ver2" = "$ver" ] || { echo "FAIL: /mongodb_exporter does not run the same binary"; exit 1; }

# Points at an unreachable MongoDB: the exporter still serves and reports
# mongodb_up 0. A short connect timeout keeps each scrape from blocking for the
# driver's default server-selection wait.
echo "Testing mongodb-exporter serves /metrics (offline)..."
cid=$(docker run -d -p 19216:9216 "$IMAGE" \
  --mongodb.uri=mongodb://127.0.0.1:1 --mongodb.direct-connect --mongodb.connect-timeout-ms=500)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
body=""
for _ in $(seq 1 45); do
  if body=$(curl -fsS --max-time 15 http://127.0.0.1:19216/metrics 2>/dev/null); then break; fi
  body=""
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ -n "$body" ] || { echo "FAIL: mongodb-exporter did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
echo "$body" | grep -qE '^mongodb_up(\{[^}]*\})? 0' \
  || { echo "FAIL: mongodb_up 0 for the unreachable target missing from response"; exit 1; }
echo "✓ mongodb_up 0 for the unreachable target"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All mongodb-exporter tests passed!"
