#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# Reloader cannot be introspected without a cluster. Verified against the built
# image: BOTH `--version` and `--help` exit fatal with "Unable to create
# Kubernetes client" before cobra ever renders output, so there is no runtime
# assertion available for the injected version string. The pkg/common.Version
# ldflag is therefore checked inside the melange build instead, where the
# sandbox still has a shell and the binary can be inspected directly.
echo "Testing reloader binary runs and is the real Reloader..."
out=$(docker run --rm "$IMAGE" 2>&1 | head -20 || true)
case "$out" in
  *"Unable to create Kubernetes client"*|*"in-cluster configuration"*|*KUBERNETES_SERVICE_HOST*)
    echo "Reloader started and failed cleanly with no cluster (as expected)" ;;
  *)
    echo "FAIL: unexpected output with no cluster:"; echo "$out"; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All reloader tests passed"
