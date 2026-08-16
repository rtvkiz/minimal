#!/bin/bash
# Smoke test for minimal-step-cli-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing step version (parity with prod)..."
docker run --rm --entrypoint /usr/bin/step "$IMAGE" version 2>&1 | grep -qiE 'Smallstep CLI/0\.[0-9]|0\.30'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "Testing bind-tools (dig)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "dig -v" 2>&1 | grep -qE "^DiG"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All step-cli-dev smoke tests passed"
