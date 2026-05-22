#!/bin/bash
# Smoke test for minimal-memcached-dev.
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing memcached version (parity with prod)..."
docker run --rm "$IMAGE" -V | grep -qE "^memcached"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/socat/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && socat -V >/dev/null 2>&1 && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing busybox nc (commonly used to send memcached stats commands)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "which nc" | grep -qE "^/(usr/)?bin/nc"

echo "✓ All memcached-dev smoke tests passed"
