#!/bin/bash
# Smoke test for minimal-kubectl-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing kubectl version (parity with prod)..."
VERSION_OUT=$(docker run --rm --entrypoint /usr/bin/kubectl "$IMAGE" version --client -o yaml)
echo "$VERSION_OUT" | grep -qE 'gitVersion: v1\.[0-9]+\.[0-9]+'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/jq/git present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && jq --version >/dev/null && git --version >/dev/null"

echo "Testing bind-tools (dig)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "dig -v" 2>&1 | grep -qE "^DiG"

echo "All minimal-kubectl-dev smoke tests passed"
