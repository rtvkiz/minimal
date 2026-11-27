#!/bin/bash
# Smoke test for minimal-julia-dev: same Julia as prod, plus the dev tooling.
set -eu
: "${IMAGE:?IMAGE env var required}"
echo "Testing julia runs with the prod entrypoint..."
docker run --rm --network none "$IMAGE" --version | grep -qE '^julia version 1\.' || { echo "FAIL: julia --version"; exit 1; }
echo "Verifying bash, apk, wget, a C compiler and git (dev only)..."
tools=$(docker run --rm --network none --entrypoint /bin/sh "$IMAGE" -c 'bash --version | head -1; apk --version; wget --version | head -1; gcc --version | head -1; git --version' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"
echo "All julia-dev tests passed!"
