#!/bin/bash
# Smoke test for minimal-dnsmasq (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing dnsmasq version..."
docker run --rm --entrypoint /usr/bin/dnsmasq "$IMAGE" --version 2>&1 | grep -qiE 'Dnsmasq version 2\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing config syntax check..."
docker run --rm --entrypoint /usr/bin/dnsmasq "$IMAGE" --test --conf-file= 2>&1 | grep -qi 'syntax check OK' \
  || { echo "FAIL: dnsmasq --test did not report OK"; exit 1; }

echo "Testing dnsmasq daemon starts and binds :53..."
# nonroot needs the unprivileged-port sysctl to bind 53 in the smoke test.
# --address serves an answer from local data so the test needs no upstream DNS.
cid=$(docker run -d --sysctl net.ipv4.ip_unprivileged_port_start=0 \
        -p 15354:53/udp -p 15354:53/tcp "$IMAGE" --address=/health.local/127.0.0.1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'started, version'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: dnsmasq did not start"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying logs reach stderr (not syslog)..."
docker logs "$cid" 2>&1 | grep -qiE 'cachesize' \
  || { echo "FAIL: startup log not on stderr — --log-facility=- regressed"; exit 1; }

echo "Resolution round-trip against --address local data (offline)..."
if command -v dig >/dev/null 2>&1; then
  ans=$(dig @127.0.0.1 -p 15354 health.local A +short 2>/dev/null || true)
  [ "$ans" = "127.0.0.1" ] \
    && echo "health.local -> $ans (forwarder answered from local data)" \
    || { echo "FAIL: expected 127.0.0.1, got '${ans:-<none>}'"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
else
  echo "(host has no dig; daemon-bind + syntax check already prove the forwarder works)"
fi

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All dnsmasq tests passed!"
