#!/bin/bash
# Smoke test for minimal-composer-dev.
# Same version check as prod, PLUS: a shell, apk and the dev utilities.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing composer version..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^Composer version 2\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected composer --version: $v"; exit 1; }

echo "Testing composer validates a manifest offline..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
printf '{"name":"minimal/smoke","description":"x","license":"MIT","require":{}}\n' > "$work/composer.json"
chmod 0644 "$work/composer.json"
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" validate 2>&1) \
  || { echo "FAIL: composer validate: $out"; exit 1; }

echo "Verifying shell, apk, unzip and curl present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'apk --version; unzip -v | head -1; curl --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All composer-dev tests passed!"
