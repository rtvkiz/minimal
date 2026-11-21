#!/bin/bash
# Smoke test for minimal-aws-node-termination-handler (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing --help (flags load)..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
for f in -node-name -enable-sqs-termination-draining -enable-spot-interruption-draining -metadata-url; do
  echo "$h" | grep -q -- "$f" || { echo "FAIL: --help is missing $f: $h"; exit 1; }
done

echo "Testing config validation rejects a missing node name..."
out=$(timeout 30 docker run --rm --network none "$IMAGE" 2>&1 || true)
echo "$out" | grep -q 'must provide a node-name' || { echo "FAIL: unexpected output without NODE_NAME: $out"; exit 1; }

echo "Testing env-driven config parses and reaches the Kubernetes client..."
# A valid IMDS-mode config gets past flag/env parsing and log setup (JSON, v2
# format) and then stops cleanly at the in-cluster client - the step a
# client-go bump would break. It must exit, not hang.
out=$(timeout 30 docker run --rm --network none -e NODE_NAME=smoke \
  -e ENABLE_SPOT_INTERRUPTION_DRAINING=true -e LOG_FORMAT_VERSION=2 -e JSON_LOGGING=true "$IMAGE" 2>&1 || true)
echo "$out" | grep -q '"message":"Using log format version 2"' || { echo "FAIL: env config not applied: $out"; exit 1; }
echo "$out" | grep -q 'unable to load in-cluster configuration' || { echo "FAIL: did not reach the kube client: $out"; exit 1; }

echo "Testing the upstream entrypoint path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = '["/node-termination-handler"]' ] || { echo "FAIL: entrypoint is $ep, upstream uses /node-termination-handler"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All aws-node-termination-handler tests passed!"
