#!/bin/bash
# Smoke test for minimal-keepalived-dev.
# Same functional checks as prod, PLUS: a shell IS present, and the network
# debugging tools (ip) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Keepalived version..."
docker run --rm --entrypoint /usr/bin/keepalived "$IMAGE" --version 2>&1 | grep -qiE 'Keepalived v2\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Validating shipped config (offline)..."
docker run --rm --entrypoint /usr/bin/keepalived "$IMAGE" \
    --config-test --use-file=/etc/keepalived/keepalived.conf 2>&1 \
  || { echo "FAIL: keepalived rejected the shipped config"; exit 1; }

echo "Testing daemon starts with VRRP capabilities..."
cid=$(docker run -d --cap-add NET_ADMIN --cap-add NET_RAW --cap-add NET_BROADCAST "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'Starting Keepalived|Startup complete|VRRP_Instance'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: keepalived did not start"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying ip (iproute2) is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v ip' >/dev/null 2>&1 \
  || { echo "FAIL: ip missing from dev image"; exit 1; }

echo "All Keepalived dev tests passed!"
