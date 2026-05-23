#!/bin/bash
# Smoke test for minimal-nginx-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing nginx version (parity with prod)..."
docker run --rm --entrypoint /usr/sbin/nginx "$IMAGE" -v 2>&1 | grep -qE "^nginx version: nginx/"

echo "Testing nginx config syntax..."
docker run --rm --entrypoint /usr/sbin/nginx "$IMAGE" -t 2>&1 | grep -q "syntax is ok"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl present (HTTP debugging)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version" >/dev/null

echo "Testing openssl CLI (TLS debugging)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "openssl version" | grep -qE "^OpenSSL"

echo "Testing bind-tools (dig)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "dig -v" 2>&1 | grep -qE "^DiG"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All nginx-dev smoke tests passed"
