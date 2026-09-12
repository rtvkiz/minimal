#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing headscale version is injected..."
docker run --rm --entrypoint /usr/bin/headscale "$IMAGE" version 2>&1 | grep -qE '0\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (main.version ldflag wrong?)"; \
       docker run --rm --entrypoint /usr/bin/headscale "$IMAGE" version 2>&1 | head -5; exit 1; }

echo "Testing headscale command tree loads..."
docker run --rm --entrypoint /usr/bin/headscale "$IMAGE" --help 2>&1 | grep -qiE 'serve|nodes|apikeys' \
  || { echo "FAIL: --help did not list expected subcommands"; exit 1; }

echo "Testing it fails cleanly with no config file..."
out=$(docker run --rm --entrypoint /usr/bin/headscale "$IMAGE" serve 2>&1 | head -20 || true)
case "$out" in
  *config*|*Config*|*"no such file"*|*"failed to"*|*"cannot"*|*"unable to"*) ;;
  *) echo "FAIL: unexpected output with no config:"; echo "$out"; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All headscale tests passed"
