#!/bin/bash
# Smoke test for minimal-cloudnative-pg (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing cloudnative-pg version..."
ver=$(docker run --rm "$IMAGE" version 2>&1 || true)
echo "$ver" | grep -qE 'Version:[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing upstream image layout (both arch binaries + /manager link)..."
# The operator globs the RELATIVE path operator/manager_* (work-dir /) to find
# instance-manager binaries per arch; both must ship, like upstream's image.
cid=$(docker create "$IMAGE")
listing=$(docker export "$cid" | tar -t)
docker rm "$cid" >/dev/null
for f in operator/manager_amd64 operator/manager_arm64 manager; do
  echo "$listing" | grep -qx "$f" || { echo "FAIL: $f missing from image"; exit 1; }
done
wd=$(docker inspect --format '{{.Config.WorkingDir}}' "$IMAGE")
[ "$wd" = "/" ] || { echo "FAIL: work-dir must be / (relative glob), got '$wd'"; exit 1; }
echo "✓ operator/manager_{amd64,arm64} and /manager present, work-dir /"

echo "Testing cloudnative-pg fails cleanly without a cluster..."
# No kubeconfig and no in-cluster service account: it must say so and exit,
# not hang. Exercises client construction — what a dependency bump would break.
out=$(timeout 30 docker run --rm "$IMAGE" controller 2>&1 || true)
case "$out" in
  *"in-cluster config"*|*KUBERNETES_SERVICE_HOST*|*"no configuration has been provided"*|*"connection refused"*) ;;
  *) echo "FAIL: unexpected output without a cluster:"; echo "$out" | tail -20; exit 1 ;;
esac
echo "✓ cloudnative-pg reported a clean startup error"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All cloudnative-pg tests passed!"
