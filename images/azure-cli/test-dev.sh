#!/bin/bash
# Smoke test for minimal-azure-cli-dev.
# Same functional checks as prod, PLUS: bash, apk, jq, git and ssh.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing az version (expect $EXPECTED)..."
v=$(docker run --rm --network none "$IMAGE" version --output json 2>&1)
echo "$v" | grep -qF "\"azure-cli\": \"$EXPECTED\"" || { echo "FAIL: unexpected az version: $v"; exit 1; }

echo "Testing az output pipes through jq (the dev-variant use case)..."
j=$(docker run --rm --network none --entrypoint /bin/bash "$IMAGE" -c \
  'az version --output json | jq -r ".\"azure-cli\""' 2>&1)
[ "$j" = "$EXPECTED" ] || { echo "FAIL: az | jq gave: $j"; exit 1; }

echo "Verifying bash, apk, git and ssh present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; git --version; ssh -V 2>&1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All azure-cli-dev tests passed!"
