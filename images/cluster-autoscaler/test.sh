#!/bin/bash
# Smoke test for minimal-cluster-autoscaler (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing cluster-autoscaler reports its version at startup..."
# No --version flag upstream: the version is logged at -v=1, then it exits
# fatally for lack of a cluster (KUBERNETES_SERVICE_HOST unset).
out=$(docker run --rm --network none "$IMAGE" --cloud-provider=clusterapi -v=1 2>&1 || true)
echo "$out" | grep -E 'Cluster Autoscaler [0-9]' | head -1
echo "$out" | grep -qE 'Cluster Autoscaler 1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not logged: $(echo "$out" | head -3)"; exit 1; }
echo "$out" | grep -q 'unable to load in-cluster configuration' \
  || { echo "FAIL: expected a clean no-cluster failure: $(echo "$out" | tail -3)"; exit 1; }
echo "✓ version logged, clean no-cluster failure"

echo "Testing every cloud provider is built in..."
help=$(docker run --rm "$IMAGE" --help 2>&1 || true)
for p in aws azure gce clusterapi hetzner; do
  echo "$help" | grep -E -- '--cloud-provider ' | grep -q "$p" \
    || { echo "FAIL: cloud provider '$p' missing from --cloud-provider"; exit 1; }
done
echo "✓ aws, azure, gce, clusterapi, hetzner present"

echo "Testing the upstream /cluster-autoscaler path (Helm chart compatibility)..."
out=$(docker run --rm --network none --entrypoint /cluster-autoscaler "$IMAGE" --help 2>&1 || true)
echo "$out" | grep -q -- '--cloud-provider' || { echo "FAIL: /cluster-autoscaler does not run"; exit 1; }
echo "✓ /cluster-autoscaler runs"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All cluster-autoscaler tests passed!"
