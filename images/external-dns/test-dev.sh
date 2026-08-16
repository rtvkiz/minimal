#!/bin/bash
# Smoke test for minimal-external-dns-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing external-dns version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '0\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying dig (bind-tools) is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v dig' >/dev/null 2>&1 \
  || { echo "FAIL: dig missing from dev image"; exit 1; }

echo "All external-dns dev tests passed!"
