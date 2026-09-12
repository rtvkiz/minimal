#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# Upstream ships controller and speaker as separate images; this one carries
# both binaries, controller as the default entrypoint and speaker selected by
# overriding it. Both must therefore be present and runnable.
#
# Neither binary has a --version flag (both use the plain `flag` package and
# define none — `-version` errors with "flag provided but not defined"). They
# do log the version at startup before touching the cluster, so that startup
# line is the assertion. metallb's version is a source constant in
# internal/version, not an -X ldflag, so this also catches a stale tarball
# being built under a bumped version number.
for bin in controller speaker; do
  echo "Testing metallb ${bin} reports its version at startup..."
  out=$(docker run --rm --entrypoint "/usr/bin/${bin}" "$IMAGE" 2>&1 | head -10 || true)

  echo "$out" | grep -qE "MetalLB ${bin} starting version [0-9]+\.[0-9]+\.[0-9]+" \
    || { echo "FAIL: ${bin} did not log its startup version line:"; echo "$out"; exit 1; }

  echo "Testing metallb ${bin} then fails cleanly with no cluster..."
  case "$out" in
    *"Unable to get namespace from pod service account"*|*METALLB_NAMESPACE*|\
    *"in-cluster"*|*KUBERNETES_SERVICE_HOST*|*"connection refused"*) ;;
    *) echo "FAIL: ${bin} gave unexpected output with no cluster:"; echo "$out"; exit 1 ;;
  esac
done

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All metallb tests passed"
