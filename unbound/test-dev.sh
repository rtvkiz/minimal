#!/bin/bash
# Smoke test for minimal-unbound-dev.
# Boots the resolver, then does a fully self-contained DNS round-trip using the
# image's OWN dig (dev ships bind-tools) against the local-data health record.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Unbound version..."
docker run --rm --entrypoint /usr/bin/unbound "$IMAGE" -V 2>&1 | grep -qiE 'Version 1\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Starting Unbound (dev)..."
cid=$(docker run -d --sysctl net.ipv4.ip_unprivileged_port_start=0 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'start of service'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: unbound did not start"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker exec "$cid" /bin/sh -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "DNS round-trip via the image's own dig (offline, local-data)..."
ans=$(docker exec "$cid" dig @127.0.0.1 health.local A +short 2>/dev/null | tr -d '\r' | head -1)
[ "$ans" = "127.0.0.1" ] \
  && echo "health.local -> $ans" \
  || { echo "FAIL: expected 127.0.0.1, got '${ans:-<none>}'"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "All Unbound dev tests passed!"
