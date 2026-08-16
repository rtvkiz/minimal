#!/bin/bash
# Smoke test for minimal-keepalived (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Keepalived version..."
docker run --rm --entrypoint /usr/bin/keepalived "$IMAGE" --version 2>&1 | grep -qiE 'Keepalived v2\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Validating shipped config (offline)..."
# --config-test parses the config and exits; it needs no network privileges,
# which is what makes it usable as a smoke test for a daemon that otherwise
# requires CAP_NET_ADMIN.
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

echo "Verifying logs reach the console (not syslog)..."
docker logs "$cid" 2>&1 | grep -qiE 'keepalived' \
  || { echo "FAIL: no startup log on console — --log-console regressed"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All Keepalived tests passed!"
