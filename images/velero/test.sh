#!/bin/bash
# Smoke test for minimal-velero (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing velero version (client-only, offline)..."
docker run --rm "$IMAGE" version --client-only 2>&1 | grep -qiE '1\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing velero help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'backup|restore|schedule' \
  || { echo "FAIL: expected backup/restore in help output"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All velero tests passed!"
