#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing tailscale CLI version..."
docker run --rm --entrypoint /usr/bin/tailscale "$IMAGE" version 2>&1 | grep -qE '^1\.[0-9]+'

echo "Testing tailscaled version (both binaries shipped)..."
docker run --rm --entrypoint /usr/bin/tailscaled "$IMAGE" --version 2>&1 | grep -qE '^1\.[0-9]+'

echo "Testing tailscaled starts in userspace-networking mode..."
# Boots the daemon without /dev/net/tun or NET_ADMIN, which is how it runs in
# Kubernetes. Proves the daemon initialises its state dir and opens its local
# API socket — not just that a version string prints.
CID=$(docker run -d "$IMAGE" --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/tmp/tailscaled.sock)
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 30); do
  logs=$(docker logs "$CID" 2>&1 || true)
  case "$logs" in
    *"logtail started"*|*"Program starting"*|*"wgengine.NewUserspaceEngine"*|*"Backend: logs"*) ok=1; break ;;
  esac
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: tailscaled did not start"; docker logs "$CID" 2>&1 | tail -20; exit 1; }

# The CLI must be able to reach the daemon over the local socket. `status`
# exits non-zero when logged out, which is expected here — what matters is that
# it talked to the daemon rather than failing to connect.
out=$(docker exec "$CID" /usr/bin/tailscale --socket=/tmp/tailscaled.sock status 2>&1 || true)
case "$out" in
  *"Logged out"*|*"NeedsLogin"*|*"stopped"*|*100.*) ;;
  *) echo "FAIL: CLI could not reach the daemon (got: $out)"; exit 1 ;;
esac
echo "✓ tailscaled started and the CLI reached it"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All tailscale tests passed!"
