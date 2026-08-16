#!/bin/bash
# Smoke test for minimal-redis-exporter (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing redis_exporter version..."
# Upstream initialises main.BuildVersion to the literal
# "<<< filled in by build >>>", so an un-injected build is unmistakable —
# assert on a real semver and explicitly reject the placeholder.
ver=$(docker run --rm --entrypoint /usr/bin/redis_exporter "$IMAGE" --version 2>&1 | head -2)
echo "$ver" | grep -qE 'Redis Metrics Exporter [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected: $ver"; exit 1; }
echo "$ver" | grep -q 'Redis Metrics Exporter <<<' \
  && { echo "FAIL: version left as upstream placeholder"; exit 1; }

echo "Testing exporter serves /metrics with no Redis present (offline)..."
# redis_exporter binds and serves regardless of target reachability — it simply
# reports redis_up 0. That makes a genuine end-to-end HTTP check possible with
# no network egress and no Redis: scrape our own endpoint and require both the
# Prometheus exposition format and the exporter's own build-info metric.
cid=$(docker run -d -p 19121:9121 "$IMAGE" --redis.addr=redis://127.0.0.1:1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if curl -fsS --max-time 3 http://127.0.0.1:19121/metrics 2>/dev/null | grep -q '^# HELP'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: exporter did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

body=$(curl -fsS --max-time 5 http://127.0.0.1:19121/metrics)
echo "$body" | grep -q 'redis_exporter_build_info' \
  || { echo "FAIL: build-info metric missing from /metrics"; exit 1; }
echo "$body" | grep -qE '^redis_up ' \
  || { echo "FAIL: redis_up metric missing from /metrics"; exit 1; }
echo "served /metrics with redis_exporter_build_info and redis_up"

echo "Verifying it reports the target as down (redis_up 0)..."
echo "$body" | grep -qE '^redis_up 0' \
  || { echo "FAIL: expected redis_up 0 against an unreachable target"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All redis-exporter tests passed!"
