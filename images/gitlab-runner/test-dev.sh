#!/bin/bash
# Smoke test for minimal-gitlab-runner-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing gitlab-runner version (parity with prod)..."
gv=$(docker run --rm --entrypoint /usr/bin/gitlab-runner "$IMAGE" --version 2>&1)
echo "$gv" | grep -qE 'Version:[[:space:]]+19\.[0-9]+' || { echo "unexpected version: $gv"; exit 1; }

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash — the dev variant exists so the shell executor works..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing git present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q 'git version'

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "All gitlab-runner-dev tests passed!"
