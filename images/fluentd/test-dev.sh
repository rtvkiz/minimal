#!/bin/bash
# Smoke test for minimal-fluentd-dev.
# Same functional checks as prod, PLUS: bash, apk, and a working native-gem toolchain.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing fluentd version (expect $EXPECTED)..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qF "fluentd $EXPECTED" || { echo "FAIL: unexpected fluentd --version: $v"; exit 1; }

echo "Testing the shipped default config parses (--dry-run)..."
d=$(docker run --rm --network none "$IMAGE" --dry-run 2>&1) || { echo "FAIL: --dry-run failed: $d"; exit 1; }
echo "$d" | grep -q 'finished dry run mode' || { echo "FAIL: dry run did not finish: $d"; exit 1; }

echo "Verifying bash, apk, fluent-gem and cc present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; fluent-gem --version; cc --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All fluentd-dev tests passed!"
