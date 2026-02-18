#!/bin/bash
set -euo pipefail

echo "Testing Caddy version..."
docker run --rm --entrypoint /usr/bin/caddy "$IMAGE" version

echo "Testing Caddy list-modules (verify standard modules loaded)..."
MODULES=$(docker run --rm --entrypoint /usr/bin/caddy "$IMAGE" list-modules 2>&1)
echo "$MODULES" | head -20

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
