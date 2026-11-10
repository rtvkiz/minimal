#!/bin/bash
# Smoke test for minimal-elasticsearch-exporter (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing elasticsearch-exporter version..."
ver=$(docker run --rm --entrypoint /usr/bin/elasticsearch_exporter "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'elasticsearch_exporter, version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing elasticsearch-exporter serves /metrics (offline)..."
# Points at an unreachable target: the exporter must still serve /metrics and
# report the target as down, which proves the collector ran, not just the server.
cid=$(docker run -d -p 19114:9114 "$IMAGE" --es.uri=http://127.0.0.1:1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:19114/metrics >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: elasticsearch-exporter did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
body=$(curl -fsS --max-time 5 http://127.0.0.1:19114/metrics)
echo "$body" | grep -qE 'elasticsearch_exporter_build_info' \
  || { echo "FAIL: elasticsearch_exporter_build_info metric missing from response"; exit 1; }
echo "✓ elasticsearch_exporter_build_info metric"
echo "$body" | grep -qE '^elasticsearch_clusterinfo_up\{[^}]*\} 0' \
  || { echo "FAIL: elasticsearch_clusterinfo_up 0 for the unreachable cluster missing from response"; exit 1; }
echo "✓ elasticsearch_clusterinfo_up 0 for the unreachable cluster"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All elasticsearch-exporter tests passed!"
