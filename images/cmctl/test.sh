#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing cmctl version..."
docker run --rm "$IMAGE" version --client 2>&1 | grep -qiE '2\.[0-9]+'

echo "Testing cmctl help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'approve|renew|status|install'

echo "Testing cmctl check offline (no cluster: exercises cobra/flag parsing)..."
docker run --rm "$IMAGE" check --help 2>&1 | grep -qiE 'check'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All cmctl tests passed!"
