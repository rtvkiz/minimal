#!/bin/bash
# Smoke test for minimal-step-ca-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing step-ca version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '0\.[0-9]+|Smallstep' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying openssl is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v openssl' >/dev/null 2>&1 \
  || { echo "FAIL: openssl missing from dev image"; exit 1; }

echo "All step-ca dev tests passed!"
