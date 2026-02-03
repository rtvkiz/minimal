#!/bin/bash
set -euo pipefail

echo "Testing Bun version..."
docker run --rm "$IMAGE" --version

echo "Testing simple script..."
docker run --rm "$IMAGE" -e 'console.log("Hello minimal bun")'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
