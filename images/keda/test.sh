#!/bin/bash
# Smoke test for minimal-keda (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing keda flags load (binary runs, usage printed)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'cert-dir|enable-prometheus-metrics|cert-secret-name'

echo "Testing keda --help exits cleanly..."
docker run --rm "$IMAGE" --help >/dev/null 2>&1
code=$?
[ "$code" -eq 0 ] || { echo "FAIL: --help exited $code, expected 0"; exit 1; }

echo "Testing keda fails cleanly with no WATCH_NAMESPACE..."
# The operator checks WATCH_NAMESPACE before touching the network and exits
# with a clear message, not a hang.
out=$(timeout 10 docker run --rm "$IMAGE" 2>&1 || true)
case "$out" in
  *"WATCH_NAMESPACE must be set"*) ;;
  *) echo "FAIL: unexpected output with no WATCH_NAMESPACE: $out"; exit 1 ;;
esac
echo "✓ keda reported a clean validation error"

echo "Testing keda fails cleanly without a cluster..."
# WATCH_NAMESPACE set, but no kubeconfig and no in-cluster service account:
# it must report that clearly and exit, not hang or panic. Exercises client
# construction and the config path — the parts a dependency bump would break.
out=$(timeout 10 docker run --rm -e WATCH_NAMESPACE=default "$IMAGE" 2>&1 || true)
case "$out" in
  *"unable to load in-cluster config"*|*KUBERNETES_SERVICE_HOST*|*"no configuration has been provided"*) ;;
  *) echo "FAIL: unexpected output without a cluster: $out"; exit 1 ;;
esac
echo "✓ keda reported a clean startup error"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All keda tests passed!"
