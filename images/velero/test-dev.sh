#!/bin/bash
# Smoke test for minimal-velero-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing velero version (client-only)..."
docker run --rm "$IMAGE" version --client-only 2>&1 | grep -qiE '1\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying jq is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v jq' >/dev/null 2>&1 \
  || { echo "FAIL: jq missing from dev image"; exit 1; }

echo "All velero dev tests passed!"
