#!/bin/bash
# Smoke test for minimal-busybox-dev.
# Same functional check as prod, PLUS: the dev minimum (bash, apk, wget) exists.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing busybox version..."
v=$(docker run --rm --network none "$IMAGE" busybox --help 2>&1 | head -1)
echo "$v" | grep -qE '^BusyBox v1\.[0-9]+' || { echo "FAIL: unexpected busybox banner: $v"; exit 1; }

echo "Testing drop-in image shape (same CMD as prod)..."
cmd=$(docker inspect --format '{{json .Config.Cmd}}' "$IMAGE")
[ "$cmd" = '["/bin/sh"]' ] || { echo "FAIL: expected CMD [\"/bin/sh\"], got $cmd"; exit 1; }
out=$(docker run --rm --network none "$IMAGE" echo drop-in-ok 2>&1)
[ "$out" = "drop-in-ok" ] || { echo "FAIL: docker run IMAGE echo: $out"; exit 1; }

echo "Verifying bash, apk and wget present (dev only)..."
tools=$(docker run --rm --network none "$IMAGE" sh -c \
  'bash --version | head -1; apk --version; wget --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All busybox-dev tests passed!"
