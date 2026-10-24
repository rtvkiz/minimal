#!/bin/bash
# Smoke test for minimal-harbor-portal-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing nginx config syntax..."
docker run --rm --entrypoint /usr/sbin/nginx "$IMAGE" -t 2>&1 | grep -q "syntax is ok"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version" >/dev/null

echo "Testing jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "jq --version" | grep -q jq

echo "✓ All harbor-portal-dev smoke tests passed"
