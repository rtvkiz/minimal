#!/bin/bash
# Smoke test for minimal-ollama-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

name="ollama-dev-test-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "Testing ollama binary + CPU backends present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/ollama && ls /usr/lib/ollama/libggml-cpu-*.so >/dev/null"

echo "Testing the HTTP API from inside the container with curl + jq..."
docker run -d --name "$name" --network none "$IMAGE" >/dev/null
out=""
for _ in $(seq 1 30); do
  out=$(docker exec "$name" sh -c 'curl -sf http://127.0.0.1:11434/api/version | jq -r .version' 2>/dev/null) && [ -n "$out" ] && break
  sleep 1
done
echo "$out" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "FAIL: /api/version: '$out'"; docker logs "$name" 2>&1 | tail -10; exit 1; }

echo "Testing bash, apk, openssl and dig present..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'apk --version && openssl version && dig -v 2>&1 | head -1'

echo "All ollama-dev tests passed!"
