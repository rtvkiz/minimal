#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing flagger version..."
# VERSION is a source constant upstream bumps per release, so this also catches
# a stale tarball being built under a new version number.
docker run --rm "$IMAGE" -version 2>&1 | grep -qE '1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version string not found"; \
       docker run --rm "$IMAGE" -version 2>&1 | head -5; exit 1; }

echo "Testing flagger flags load..."
docker run --rm "$IMAGE" -help 2>&1 | grep -qiE 'kubeconfig|mesh-provider|metrics-server' \
  || { echo "FAIL: -help did not list expected flags"; exit 1; }

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All flagger tests passed"
