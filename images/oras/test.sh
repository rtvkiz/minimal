#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing oras version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'Version:[[:space:]]*v?1\.[0-9]'

echo "Testing oras help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'push|pull|manifest'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All oras tests passed!"
