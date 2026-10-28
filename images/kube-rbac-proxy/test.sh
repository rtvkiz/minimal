#!/bin/bash
# Smoke test for minimal-kube-rbac-proxy (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing kube-rbac-proxy version..."
ver=$(docker run --rm "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'kube-rbac-proxy v[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }
echo "$ver" | grep -q "v0.0.0" && { echo "FAIL: version not injected"; exit 1; } || true

echo "Testing kube-rbac-proxy fails cleanly without a cluster..."
# No kubeconfig and no in-cluster service account: it must say so and exit,
# not hang. Exercises client construction — what a dependency bump would break.
out=$(timeout 30 docker run --rm "$IMAGE" --upstream=http://127.0.0.1:1/ --insecure-listen-address=0.0.0.0:8080 2>&1 || true)
case "$out" in
  *"in-cluster config"*|*KUBERNETES_SERVICE_HOST*|*"no configuration has been provided"*|*"connection refused"*) ;;
  *) echo "FAIL: unexpected output without a cluster:"; echo "$out" | tail -20; exit 1 ;;
esac
echo "✓ kube-rbac-proxy reported a clean startup error"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All kube-rbac-proxy tests passed!"
