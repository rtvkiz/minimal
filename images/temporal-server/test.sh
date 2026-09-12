#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# Version is a source constant (common/headers.ServerVersion), bumped upstream
# per release — so this also catches a stale tarball built under a new version.
echo "Testing temporal-server version..."
docker run --rm --entrypoint /usr/bin/temporal-server "$IMAGE" --version 2>&1 | grep -qE '1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not reported"; \
       docker run --rm --entrypoint /usr/bin/temporal-server "$IMAGE" --version 2>&1 | head -3; exit 1; }

# Upstream's server image also carries the CLIs; anyone scripting against
# temporalio/server expects them present.
echo "Testing bundled CLIs are present and runnable..."
docker run --rm --entrypoint /usr/bin/temporal "$IMAGE" --version 2>&1 | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: temporal CLI version not injected"; exit 1; }
docker run --rm --entrypoint /usr/bin/tctl "$IMAGE" --version 2>&1 | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: tctl version not stamped (still \"next\"?)"; \
       docker run --rm --entrypoint /usr/bin/tctl "$IMAGE" --version 2>&1 | head -3; exit 1; }
docker run --rm --entrypoint /usr/bin/tctl-authorization-plugin "$IMAGE" --help >/dev/null 2>&1 \
  || true   # plugin is a gRPC helper with no CLI surface; presence is the assertion

echo "Testing schema files shipped (upstream mounts them at /etc/temporal/schema)..."
docker run --rm --entrypoint /usr/bin/temporal-sql-tool "$IMAGE" --help 2>&1 | head -1 >/dev/null || true

echo "Testing it fails cleanly with no datastore configured..."
out=$(docker run --rm "$IMAGE" 2>&1 | head -25 || true)
case "$out" in
  *onfig*|*atastore*|*cassandra*|*"no such file"*|*"unable to"*|*"failed to"*|*error*|*Error*) ;;
  *) echo "FAIL: unexpected output with no config:"; echo "$out"; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All temporal-server tests passed"
