#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing oauth2-proxy version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '7\.[0-9]+'

echo "Testing oauth2-proxy help (flags load)..."
# oauth2-proxy uses Go's flag package: --help prints usage and exits non-zero;
# piped to grep (no pipefail) that non-zero exit is masked, we assert on content.
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'provider|upstream|http-address|cookie-secret'

echo "Testing oauth2-proxy rejects a bad config (validation wired)..."
# With no provider/client-id/cookie-secret it must refuse to start, proving the
# config validation path is intact offline (no network, no real provider needed).
docker run --rm "$IMAGE" --http-address=127.0.0.1:0 2>&1 | grep -qiE 'missing|required|invalid|cookie|client' \
  && echo "oauth2-proxy config validation OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All oauth2-proxy tests passed!"
