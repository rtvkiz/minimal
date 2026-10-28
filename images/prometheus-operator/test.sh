#!/bin/bash
# Smoke test for minimal-prometheus-operator (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing prometheus-operator version..."
ver=$(docker run --rm "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'prometheus-operator, version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing prometheus-operator fails cleanly without a cluster..."
# No kubeconfig and no in-cluster service account: it must say so and exit,
# not hang. Exercises client construction — what a dependency bump would break.
out=$(timeout 30 docker run --rm "$IMAGE" 2>&1 || true)
case "$out" in
  *"in-cluster config"*|*KUBERNETES_SERVICE_HOST*|*"no configuration has been provided"*|*"connection refused"*) ;;
  *) echo "FAIL: unexpected output without a cluster:"; echo "$out" | tail -20; exit 1 ;;
esac
echo "✓ prometheus-operator reported a clean startup error"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All prometheus-operator tests passed!"
