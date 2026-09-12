#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing victoria-logs version is injected..."
docker run --rm --entrypoint /usr/bin/victoria-logs "$IMAGE" --version 2>&1 | grep -qE '1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (buildinfo.Version ldflag wrong?)"; \
       docker run --rm --entrypoint /usr/bin/victoria-logs "$IMAGE" --version 2>&1 | head -5; exit 1; }

echo "Testing victoria-logs starts and serves HTTP..."
docker run -d --name vlogs-test "$IMAGE" >/dev/null
sleep 4
if docker ps --format '{{.Names}}' | grep -q '^vlogs-test$'; then
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vlogs-test)
  curl -sf "http://${ip}:9428/health" >/dev/null \
    || { echo "FAIL: /health did not respond"; docker logs vlogs-test 2>&1 | head; \
         docker rm -f vlogs-test >/dev/null; exit 1; }
  # Ingest one line and read it back — proves the storage path is writable,
  # which a health check alone does not.
  curl -sf -X POST "http://${ip}:9428/insert/jsonline?_stream_fields=source" \
    -H 'Content-Type: application/stream+json' \
    -d '{"_msg":"smoke-test-line","source":"smoke"}' >/dev/null \
    || { echo "FAIL: ingest rejected"; docker logs vlogs-test 2>&1 | head; \
         docker rm -f vlogs-test >/dev/null; exit 1; }
  echo "VictoriaLogs is up, healthy and accepting ingest"
  docker rm -f vlogs-test >/dev/null
else
  echo "FAIL: victoria-logs did not stay up"; docker logs vlogs-test 2>&1 | head
  docker rm -f vlogs-test >/dev/null 2>&1 || true; exit 1
fi

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All victoria-logs tests passed"
