#!/bin/bash
set -euo pipefail

cleanup() { docker rm -f flink-dev-test >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing Java version (parity with prod)..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -q "21\."

echo "Testing dev tooling is present..."
for tool in /bin/sh /bin/bash /usr/bin/curl /usr/bin/jq /usr/bin/ps; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x $tool" \
    || { echo "missing dev tool: $tool"; exit 1; }
done

echo "Starting Flink jobmanager and waiting for its REST API..."
docker run -d --name flink-dev-test "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 45); do
  sleep 2
  docker ps --format '{{.Names}}' | grep -q '^flink-dev-test$' || break
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' flink-dev-test)
  if curl -sf "http://${IP}:8081/overview" >/dev/null 2>&1; then ready=1; break; fi
done

if [ "$ready" -ne 1 ]; then
  echo "Flink (dev) jobmanager did not become ready"
  docker logs flink-dev-test 2>&1 | tail -40 || true
  exit 1
fi

# curl is in this image specifically for API poking — exercise it from inside.
inside=$(docker exec flink-dev-test /bin/sh -c "curl -sf http://localhost:8081/config")
echo "$inside" | grep -q "flink-version" \
  || { echo "in-container curl to the REST API failed: $inside"; exit 1; }

echo "✓ All flink-dev smoke tests passed"
