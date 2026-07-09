#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing gitleaks version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '(v?)8\.[0-9]'

echo "Testing gitleaks help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'git|dir|stdin'

echo "Testing gitleaks scan of a clean directory (fully offline)..."
work=$(mktemp -d); chmod 0777 "$work"
printf 'hello world\n' > "$work/clean.txt"
# scan a directory with no secrets; embedded ruleset must load; exit 0 = no leaks
docker run --rm -v "$work:/workspace" "$IMAGE" dir /workspace --no-banner
echo "gitleaks scan OK (no leaks on clean dir)"
rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All gitleaks tests passed!"
