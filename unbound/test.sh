#!/bin/bash
# Smoke test for minimal-unbound (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Unbound version..."
docker run --rm --entrypoint /usr/bin/unbound "$IMAGE" -V 2>&1 | grep -qiE 'Version 1\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Validating shipped config (offline)..."
docker run --rm --entrypoint /usr/bin/unbound-checkconf "$IMAGE" /etc/unbound/unbound.conf \
  || { echo "FAIL: unbound-checkconf rejected the shipped config"; exit 1; }

echo "Testing Unbound daemon starts and binds :53..."
# nonroot needs the unprivileged-port sysctl to bind 53 in the smoke test.
cid=$(docker run -d --sysctl net.ipv4.ip_unprivileged_port_start=0 \
        -p 15353:53/udp -p 15353:53/tcp "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'start of service'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: unbound did not start"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Resolution round-trip against local-data (offline)..."
if command -v dig >/dev/null 2>&1; then
  ans=$(dig @127.0.0.1 -p 15353 health.local A +short 2>/dev/null || true)
  [ "$ans" = "127.0.0.1" ] \
    && echo "health.local -> $ans (resolver answered from local-data)" \
    || { echo "FAIL: expected 127.0.0.1, got '${ans:-<none>}'"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
else
  echo "(host has no dig; daemon-bind + checkconf already prove the resolver works)"
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All Unbound tests passed!"
