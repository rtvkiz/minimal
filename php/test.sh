#!/bin/bash
set -euo pipefail

echo "Testing PHP version..."
docker run --rm "$IMAGE" -v

echo "Testing PHP execution..."
docker run --rm "$IMAGE" -r "echo 'Hello minimal php';"

echo "Testing common extensions (json, openssl)..."
docker run --rm "$IMAGE" -r "var_dump(extension_loaded('json'), extension_loaded('openssl'));"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
