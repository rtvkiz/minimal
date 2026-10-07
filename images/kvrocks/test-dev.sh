#!/bin/bash
# Smoke test for minimal-kvrocks-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing kvrocks version (parity with prod)..."
docker run --rm --entrypoint /usr/bin/kvrocks "$IMAGE" -v | grep -qiE 'kvrocks.*2\.'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing valkey-cli present (RESP client)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "valkey-cli --version" | grep -qE "^valkey-cli"

echo "Testing curl/socat/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && socat -V >/dev/null 2>&1 && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing kvrocks + valkey-cli round trip..."
net="kvrocks-test-net-$$"
docker network create "$net" >/dev/null 2>&1 || true
cid=$(docker run -d --network "$net" --name kvrocks-srv-$$ "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker logs "$cid" 2>&1 | grep -qiE 'ready to accept connections|listening'; then ok=1; break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: kvrocks did not come up"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

pong=$(docker run --rm --network "$net" --entrypoint /usr/bin/valkey-cli "$IMAGE" -h "kvrocks-srv-$$" -p 6666 PING)
echo "$pong" | grep -qi PONG || { echo "FAIL: PING did not return PONG (got: $pong)"; exit 1; }

echo "✓ All kvrocks-dev smoke tests passed"
