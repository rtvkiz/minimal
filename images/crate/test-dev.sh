#!/bin/bash
# Smoke test for minimal-crate-dev: same CrateDB as prod, plus network tooling.
set -eu
: "${IMAGE:?IMAGE env var required}"
name="minimal-crate-dev-smoke-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
echo "Starting a single node..."
docker run -d --name "$name" -e JAVA_TOOL_OPTIONS=-Xmx512m "$IMAGE" >/dev/null
echo "Querying it from inside the container with the dev curl..."
for i in $(seq 1 120); do
  out=$(docker exec "$name" curl -sf --max-time 5 -H 'Content-Type: application/json' -d '{"stmt":"select 41 + 1"}' http://127.0.0.1:4200/_sql 2>/dev/null) && break
  sleep 1
done
echo "$out" | grep -q '"rows":\[\[42\]\]' || { echo "FAIL: in-container SQL: ${out:-no response}"; docker logs "$name" 2>&1 | tail -20; exit 1; }
echo "Verifying bash, apk, wget, openssl and dig (dev only)..."
docker exec "$name" sh -c 'bash --version | head -1; apk --version; wget --version | head -1; openssl version; dig -v 2>&1 | head -1' \
  || { echo "FAIL: dev tooling missing"; exit 1; }
echo "All crate-dev tests passed!"
