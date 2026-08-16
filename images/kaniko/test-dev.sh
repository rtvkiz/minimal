#!/bin/bash
# Smoke test for minimal-kaniko-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kaniko executor version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'v?1\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying git is present (git-context builds)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v git' >/dev/null 2>&1 \
  || { echo "FAIL: git missing from dev image"; exit 1; }

echo "All kaniko dev tests passed!"
