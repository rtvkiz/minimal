#!/bin/bash
# Smoke test for minimal-adminer-dev.
# Same entrypoint as prod (serves Adminer), PLUS: a shell, apk and curl.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
port=18082
trap 'docker rm -f "adminer-dev-$$" >/dev/null 2>&1 || true' EXIT

echo "Testing Adminer serves its login page..."
docker run -d --name "adminer-dev-$$" -p "127.0.0.1:${port}:8080" "$IMAGE" >/dev/null
page=""
for _ in $(seq 1 30); do page=$(curl -sf "http://127.0.0.1:${port}/" 2>/dev/null) && break; sleep 1; done
echo "$page" | grep -q "$EXPECTED" || { echo "FAIL: login page does not show Adminer $EXPECTED"; exit 1; }

echo "Verifying shell, apk and curl present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'apk --version; curl --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All adminer-dev tests passed!"
