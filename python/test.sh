#!/bin/bash
set -euo pipefail

echo "Testing Python interpreter..."
docker run --rm "$IMAGE" -c "import sys; print(f'Python {sys.version}')"

echo "Testing TLS/SSL..."
docker run --rm "$IMAGE" -c "import ssl; print('TLS OK:', ssl.OPENSSL_VERSION)"

echo "Testing stdlib modules..."
docker run --rm "$IMAGE" -c "import json, hashlib, http.client; print('stdlib OK')"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
