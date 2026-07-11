#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing trufflehog version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '3\.[0-9]' \
  || docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '3\.[0-9]'

echo "Testing trufflehog help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE '[a-z]'
echo "Testing trufflehog filesystem scan (offline, clean dir)..."
work=$(mktemp -d); chmod 0777 "$work"; printf "nothing secret here\n" > "$work/f.txt"
docker run --rm -v "$work:/workspace" "$IMAGE" filesystem /workspace --no-update --no-verification >/dev/null 2>&1
echo "trufflehog scan OK"; rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All trufflehog tests passed!"
