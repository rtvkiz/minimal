#!/bin/bash
set -euo pipefail

echo "Testing HAProxy version..."
docker run --rm --entrypoint /usr/bin/haproxy "$IMAGE" -v

echo "Testing HAProxy build options (verify USE_OPENSSL, USE_PCRE2)..."
docker run --rm --entrypoint /usr/bin/haproxy "$IMAGE" -vv 2>&1 | grep -E "(USE_OPENSSL|USE_PCRE2)" || {
  echo "FAIL: Expected USE_OPENSSL and USE_PCRE2 in build options"
  exit 1
}

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
