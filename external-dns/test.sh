#!/bin/bash
# Smoke test for minimal-external-dns (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing external-dns version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '0\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing external-dns help (flags load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE -- '--provider|--source' \
  || { echo "FAIL: expected --provider/--source in help output"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All external-dns tests passed!"
