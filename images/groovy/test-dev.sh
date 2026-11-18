#!/bin/bash
# Smoke test for minimal-groovy-dev.
# Same Groovy as prod, PLUS: shell, apk, git and a full JDK (javac).
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing groovy version is $EXPECTED..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -q "Groovy Version: ${EXPECTED} " || { echo "FAIL: unexpected groovy --version: $v"; exit 1; }

echo "Testing an inline expression..."
out=$(docker run --rm --network none "$IMAGE" -e 'println "dev-" + (6 * 7)' 2>&1)
[ "$out" = "dev-42" ] || { echo "FAIL: inline expression: $out"; exit 1; }

echo "Verifying shell, apk, git and javac present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'apk --version; git --version; /usr/lib/jvm/java-25-openjdk/bin/javac -version' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All groovy-dev tests passed!"
