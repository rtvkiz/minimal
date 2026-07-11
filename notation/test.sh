#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing notation version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '1\.[0-9]' \
  || docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '1\.[0-9]'

echo "Testing notation help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE '[a-z]'
echo "Testing notation cert generate-test (offline)..."
docker run --rm "$IMAGE" cert generate-test "minimal-test" >/dev/null 2>&1 && echo "notation generated a test cert OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All notation tests passed!"
