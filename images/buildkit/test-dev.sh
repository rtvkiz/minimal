#!/bin/bash
# Smoke test for minimal-buildkit-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing buildctl version (parity with prod)..."
cv=$(docker run --rm --entrypoint /usr/bin/buildctl "$IMAGE" --version 2>&1)
echo "$cv" | grep -qE 'buildctl .* v0\.[0-9]+' || { echo "unexpected version: $cv"; exit 1; }

echo "Testing buildkitd and runc are present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "buildkitd --version && runc --version" 2>&1 | grep -q 'runc version'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "All buildkit-dev tests passed!"
