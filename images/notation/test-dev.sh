#!/bin/bash
# Smoke test for minimal-notation-dev.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing notation version (parity with prod)..."
docker run --rm --entrypoint /usr/bin/notation "$IMAGE" version 2>&1 | grep -qiE '1\.[0-9]' \
  || docker run --rm --entrypoint /usr/bin/notation "$IMAGE" --version 2>&1 | grep -qiE '1\.[0-9]'

echo "Testing /bin/sh + /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok
echo "Testing curl/openssl/jq/git present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && git --version >/dev/null"

echo "✓ All notation-dev smoke tests passed"
