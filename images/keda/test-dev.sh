#!/bin/bash
# Smoke test for minimal-keda-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing keda binary (parity with prod)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'cert-dir|enable-prometheus-metrics'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl and jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version && jq --version" >/dev/null

echo "All keda-dev tests passed!"
