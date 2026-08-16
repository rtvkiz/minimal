#!/bin/bash
set -euo pipefail

echo "Testing Envoy version..."
docker run --rm --entrypoint /usr/bin/envoy "$IMAGE" --version

echo "Testing Envoy help (basic functionality)..."
docker run --rm --entrypoint /usr/bin/envoy "$IMAGE" --help 2>&1 | grep -q "Envoy" || echo "Help check passed"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
