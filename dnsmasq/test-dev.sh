#!/bin/bash
# Smoke test for minimal-dnsmasq-dev.
# Same functional checks as prod, PLUS: a shell IS present, and the DNS
# debugging tools (dig) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing dnsmasq version..."
docker run --rm --entrypoint /usr/bin/dnsmasq "$IMAGE" --version 2>&1 | grep -qiE 'Dnsmasq version 2\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing dnsmasq daemon starts and binds :53..."
cid=$(docker run -d --sysctl net.ipv4.ip_unprivileged_port_start=0 \
        -p 15355:53/udp -p 15355:53/tcp "$IMAGE" --address=/health.local/127.0.0.1)
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'started, version'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: dnsmasq did not start"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Resolution round-trip using the image's own dig (no host tooling needed)..."
ans=$(docker run --rm --network "container:$cid" --entrypoint /usr/bin/dig "$IMAGE" \
        @127.0.0.1 health.local A +short 2>/dev/null || true)
[ "$ans" = "127.0.0.1" ] \
  && echo "health.local -> $ans (resolved via in-image dig)" \
  || { echo "FAIL: expected 127.0.0.1, got '${ans:-<none>}'"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying dig (DNS client) is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v dig' >/dev/null 2>&1 \
  || { echo "FAIL: dig missing from dev image"; exit 1; }

echo "All dnsmasq dev tests passed!"
