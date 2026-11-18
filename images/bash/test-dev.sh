#!/bin/bash
# Smoke test for minimal-bash-dev.
# Same functional check as prod, PLUS: apk works and the dev utilities exist.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing bash version..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^GNU bash, version 5\.[0-9]+' || { echo "FAIL: unexpected bash --version: $v"; exit 1; }

echo "Testing an associative array (bash-only feature)..."
out=$(docker run --rm --network none "$IMAGE" -c 'declare -A m=([k]=v); echo "${m[k]}"' 2>&1)
[ "$out" = "v" ] || { echo "FAIL: assoc array: $out"; exit 1; }

echo "Verifying apk, curl, jq, git and GNU utilities present (dev only)..."
tools=$(docker run --rm "$IMAGE" -c \
  'apk --version; curl --version | head -1; jq --version; git --version; ls --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All bash-dev tests passed!"
