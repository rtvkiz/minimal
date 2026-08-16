#!/bin/bash
# Smoke test for minimal-pgbouncer-dev.
# Same functional checks as prod, PLUS: a shell IS present, and the debugging
# tools (psql for the admin console) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing PgBouncer version..."
docker run --rm --entrypoint /usr/bin/pgbouncer "$IMAGE" --version 2>&1 | grep -qiE 'PgBouncer 1\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing PgBouncer starts and listens on :6432..."
cid=$(docker run -d -p 16433:6432 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 15); do
  if docker logs "$cid" 2>&1 | grep -qiE 'process up|listening on'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: pgbouncer did not come up"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying psql (admin console client) is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v psql' >/dev/null 2>&1 \
  || { echo "FAIL: psql missing from dev image"; exit 1; }

echo "All PgBouncer dev tests passed!"
