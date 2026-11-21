#!/bin/bash
# Smoke test for minimal-curl-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

echo "Testing curl version (parity with prod)..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^curl 8\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected curl --version: $v"; exit 1; }

echo "Testing a curl | jq pipeline through the shell..."
work=$(mktemp -d); chmod 0777 "$work"; trap 'rm -rf "$work"' EXIT
echo '{"ok":"pipe-ok"}' > "$work/in.json"; chmod 0644 "$work/in.json"
out=$(docker run --rm --network none -v "$work:/work" --entrypoint /bin/sh "$IMAGE" -c 'curl -sS file:///work/in.json | jq -r .ok' 2>&1)
[ "$out" = "pipe-ok" ] || { echo "FAIL: curl | jq: $out"; exit 1; }

echo "Testing bash, apk, openssl and dig present..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'apk --version && openssl version && dig -v 2>&1 | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All curl-dev tests passed!"
