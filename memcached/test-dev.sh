#!/bin/bash
# Smoke test for minimal-memcached-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

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

# Note: `nc`/`netcat` is NOT bundled with Wolfi's busybox build.
# To send raw memcached protocol commands (`stats`, `version`, etc.),
# use `socat - TCP:localhost:11211` instead, or `apk add netcat-openbsd`.

echo "✓ All memcached-dev smoke tests passed"
