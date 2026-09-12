#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# Upstream ships controller and speaker as separate images; this one carries
# both binaries, with controller as the default entrypoint and speaker selected
# by overriding it. Both must therefore be present and runnable.
echo "Testing metallb controller version..."
docker run --rm --entrypoint /usr/bin/controller "$IMAGE" --version 2>&1 | grep -qE '0\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: controller version not reported"; \
       docker run --rm --entrypoint /usr/bin/controller "$IMAGE" --version 2>&1 | head -5; exit 1; }

echo "Testing metallb speaker is present and runnable..."
docker run --rm --entrypoint /usr/bin/speaker "$IMAGE" --version 2>&1 | grep -qE '0\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: speaker version not reported"; \
       docker run --rm --entrypoint /usr/bin/speaker "$IMAGE" --version 2>&1 | head -5; exit 1; }

echo "Testing controller fails cleanly with no cluster..."
out=$(docker run --rm --entrypoint /usr/bin/controller "$IMAGE" 2>&1 | head -30 || true)
case "$out" in
  *"in-cluster"*|*KUBERNETES_SERVICE_HOST*|*"unable to"*|*"failed to"*|*"cannot"*|*"connection refused"*|*NAMESPACE*|*namespace*) ;;
  *) echo "FAIL: unexpected output with no cluster:"; echo "$out"; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All metallb tests passed"
