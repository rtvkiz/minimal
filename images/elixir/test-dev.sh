#!/bin/bash
# Smoke test for minimal-elixir-dev: same Elixir as prod, plus the dev tooling.
set -eu
: "${IMAGE:?IMAGE env var required}"
echo "Testing elixir runs..."
docker run --rm --network none "$IMAGE" elixir --version | grep -qE '^Elixir 1\.' || { echo "FAIL: elixir --version"; exit 1; }
echo "Verifying bash, apk, wget, a C compiler and git (dev only)..."
tools=$(docker run --rm --network none "$IMAGE" sh -c 'bash --version | head -1; apk --version; wget --version | head -1; gcc --version | head -1; git --version' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"
echo "All elixir-dev tests passed!"
