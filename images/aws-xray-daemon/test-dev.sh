#!/bin/bash
# Smoke test for minimal-aws-xray-daemon-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing aws-xray-daemon binary present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/xray"

echo "Testing /bin/sh (busybox)..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok")
[ "$out" = "sh-ok" ] || { echo "FAIL: sh: $out"; exit 1; }

echo "Testing /bin/bash..."
out=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok")
[ "$out" = "bash-ok" ] || { echo "FAIL: bash: $out"; exit 1; }

echo "Testing apk-tools present..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version")
echo "$out" | grep -q apk-tools || { echo "FAIL: apk: $out"; exit 1; }

echo "Testing curl/openssl/jq/dig present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v 2>&1 | grep -qE '^DiG'"

echo "✓ All aws-xray-daemon-dev smoke tests passed"
