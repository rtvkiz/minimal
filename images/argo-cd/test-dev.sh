#!/bin/bash
# Smoke test for minimal-argo-cd-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing argocd version (parity with prod)..."
v=$(docker run --rm "$IMAGE" version --client 2>&1)
echo "$v" | grep -qE 'argocd: v[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected version output: $v"; exit 1; }

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl and jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version && jq --version" >/dev/null

echo "All argo-cd-dev tests passed!"
