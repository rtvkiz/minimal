#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing opa version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'Version:[[:space:]]*v?1\.[0-9]'

echo "Testing opa help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'eval|run|test'

echo "Testing opa eval (Rego engine, fully offline)..."
docker run --rm "$IMAGE" eval --format=json '1 + 1' 2>&1 | grep -qE '"value":[[:space:]]*2'
echo "opa eval OK (Rego evaluation works)"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All opa tests passed!"
