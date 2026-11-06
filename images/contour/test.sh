#!/bin/bash
# Smoke test for minimal-contour (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing contour version..."
ver=$(docker run --rm "$IMAGE" version 2>&1 || true)
echo "$ver" | grep -E '^version:'
echo "$ver" | grep -qE '^version: v1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing contour bootstrap renders an Envoy bootstrap (offline)..."
# `contour bootstrap` is what the Envoy initContainer runs: a pure render, no
# cluster needed. --network none proves it.
boot=$(docker run --rm --network none "$IMAGE" bootstrap /dev/stdout \
  --xds-address=127.0.0.1 --xds-port=8001 2>/dev/null)
echo "$boot" | grep -q '"static_resources"' || { echo "FAIL: no static_resources in bootstrap: $(echo "$boot" | head -c 200)"; exit 1; }
echo "$boot" | grep -q '"cluster_name":"contour"' || { echo "FAIL: bootstrap lacks the contour xDS cluster"; exit 1; }
echo "✓ bootstrap rendered"

echo "Testing serve fails cleanly with no cluster..."
out=$(docker run --rm --network none "$IMAGE" serve --incluster 2>&1 || true)
echo "$out" | grep -q 'unable to load in-cluster configuration' \
  || { echo "FAIL: unexpected serve output: $(echo "$out" | tail -3)"; exit 1; }
echo "✓ serve reports the missing in-cluster config"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All contour tests passed!"
