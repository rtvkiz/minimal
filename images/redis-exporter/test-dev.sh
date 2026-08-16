#!/bin/bash
# Smoke test for minimal-redis-exporter-dev.
# Same functional checks as prod, PLUS: a shell IS present and the Redis /
# HTTP debugging tools are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing redis_exporter version..."
docker run --rm --entrypoint /usr/bin/redis_exporter "$IMAGE" --version 2>&1 | head -2 \
  | grep -qE 'Redis Metrics Exporter [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected"; exit 1; }

echo "Testing exporter serves /metrics with no Redis present (offline)..."
cid=$(docker run -d -p 19122:9121 "$IMAGE" --redis.addr=redis://127.0.0.1:1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if curl -fsS --max-time 3 http://127.0.0.1:19122/metrics 2>/dev/null | grep -q 'redis_exporter_build_info'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: exporter did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying redis client and HTTP tools are present..."
for t in valkey-cli curl jq openssl dig; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $t" >/dev/null 2>&1 \
    || { echo "FAIL: $t missing from dev image"; exit 1; }
done

echo "All redis-exporter dev tests passed!"
