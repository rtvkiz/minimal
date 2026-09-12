#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing reloader version is injected..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qE '1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (pkg/common.Version ldflag wrong?)"; \
       docker run --rm "$IMAGE" --version 2>&1 | head -5; exit 1; }

echo "Testing reloader command tree loads..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'reload|resource|namespace' \
  || { echo "FAIL: --help did not list expected flags"; exit 1; }

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All reloader tests passed"
