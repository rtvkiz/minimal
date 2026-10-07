#!/bin/bash
# Smoke test for minimal-kvrocks (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Kvrocks version..."
docker run --rm --entrypoint /usr/bin/kvrocks "$IMAGE" -v 2>&1 | grep -qiE 'kvrocks.*2\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing Kvrocks help..."
docker run --rm --entrypoint /usr/bin/kvrocks "$IMAGE" -h 2>&1 | grep -qiE 'usage|config' \
  || { echo "FAIL: help text not found"; exit 1; }

echo "Testing Kvrocks starts and speaks RESP on :6666..."
cid=$(docker run -d -p 16666:6666 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker logs "$cid" 2>&1 | grep -qiE 'ready to accept connections|listening'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
if [ "$ok" != 1 ]; then
  echo "FAIL: kvrocks did not come up"; docker logs "$cid" 2>&1 | tail -30; exit 1
fi

echo "Sending RESP PING to :16666..."
exec 3<>/dev/tcp/127.0.0.1/16666
printf '*1\r\n$4\r\nPING\r\n' >&3
resp=$(head -c 7 <&3 || true)
exec 3<&- 3>&-
echo "$resp" | grep -q "PONG" \
  || { echo "FAIL: did not get PONG (got: $resp)"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All Kvrocks tests passed!"
