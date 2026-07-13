#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing kustomize version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '5\.[0-9]+'

echo "Testing kustomize help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'build|edit|create|cfg'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All kustomize tests passed!"
