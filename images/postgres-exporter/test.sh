#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing postgres_exporter version is injected..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qE '0\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (prometheus/common/version ldflag wrong?)"; \
       docker run --rm "$IMAGE" --version 2>&1 | head -5; exit 1; }

echo "Testing postgres_exporter flags load..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'web.listen-address|collector' \
  || { echo "FAIL: --help did not list expected flags"; exit 1; }

echo "Testing it serves /metrics with no database configured..."
docker run -d --name pgexp-test "$IMAGE" >/dev/null
sleep 3
if docker ps --format '{{.Names}}' | grep -q '^pgexp-test$'; then
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pgexp-test)
  # No DSN is set, so scrapes fail — but the exporter must still serve its own
  # process metrics. That distinguishes "running" from "crash-looping".
  curl -sf "http://${ip}:9187/metrics" | grep -q 'go_goroutines' \
    || { echo "FAIL: /metrics did not serve process metrics"; docker logs pgexp-test 2>&1 | head; \
         docker rm -f pgexp-test >/dev/null; exit 1; }
  echo "Exporter serves /metrics"
  docker rm -f pgexp-test >/dev/null
else
  echo "FAIL: exporter did not stay up"; docker logs pgexp-test 2>&1 | head
  docker rm -f pgexp-test >/dev/null 2>&1 || true; exit 1
fi

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All postgres-exporter tests passed"
