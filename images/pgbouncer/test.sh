#!/bin/bash
# Smoke test for minimal-pgbouncer (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing PgBouncer version..."
docker run --rm --entrypoint /usr/bin/pgbouncer "$IMAGE" --version 2>&1 | grep -qiE 'PgBouncer 1\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing PgBouncer starts and listens on :6432..."
cid=$(docker run -d -p 16432:6432 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'process up|listening on'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
if [ "$ok" != 1 ]; then
  echo "FAIL: pgbouncer did not come up"; docker logs "$cid" 2>&1 | tail -20; exit 1
fi

echo "Verifying the pooler accepts TCP connections on :6432..."
(exec 3<>/dev/tcp/127.0.0.1/16432) 2>/dev/null \
  && echo "port 6432 accepts connections" \
  || { echo "FAIL: cannot connect to :6432"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All PgBouncer tests passed!"
