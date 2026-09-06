#!/bin/bash
# Smoke test for minimal-nsq-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing nsqd version (parity with prod)..."
nv=$(docker run --rm --entrypoint /usr/bin/nsqd "$IMAGE" --version 2>&1)
echo "$nv" | grep -qE 'nsqd v1\.[0-9]+' || { echo "unexpected version: $nv"; exit 1; }

echo "Testing nsqlookupd and nsqadmin are present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "nsqlookupd --version && nsqadmin --version" 2>&1 | grep -q 'nsqadmin v1'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "All nsq-dev tests passed!"
