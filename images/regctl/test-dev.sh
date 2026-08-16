#!/bin/bash
# Smoke test for minimal-regctl-dev.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing regctl version (parity with prod)..."
docker run --rm --entrypoint /usr/bin/regctl "$IMAGE" version 2>&1 | grep -qiE '0\.[0-9]+'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All regctl-dev smoke tests passed"
