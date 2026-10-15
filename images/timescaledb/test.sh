#!/bin/bash
set -euo pipefail
: "${IMAGE:?IMAGE env var required}"

echo "Testing PostgreSQL version..."
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version | grep -qiE 'PostgreSQL\) 18\.' \
  || { echo "FAIL: postgres 18 version string not found"; exit 1; }

echo "Testing initdb can initialise a fresh PGDATA..."
# REGRESSION GUARD: initdb runs `"postgres" -V` via popen(), which execs /bin/sh.
# Same postgres-family exception as postgres-slim/patroni — prod carries busybox.
docker run --rm --tmpfs /pgtest:uid=70,gid=70,mode=0700 \
  --entrypoint /usr/bin/initdb "$IMAGE" -D /pgtest -U postgres --auth=trust 2>&1 \
  | grep -qi 'Success' \
  || { echo "FAIL: initdb could not initialise a data dir (missing /bin/sh?)"; exit 1; }

echo "Testing PostgreSQL starts with timescaledb preloaded and CREATE EXTENSION works..."
docker rm -f timescaledb-test >/dev/null 2>&1 || true
cid=$(docker run -d --name timescaledb-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --entrypoint /bin/sh "$IMAGE" \
  -c 'initdb -D "$PGDATA" -U postgres --auth=trust && exec postgres -D "$PGDATA" -h 0.0.0.0 -c shared_preload_libraries=timescaledb')
trap 'docker rm -f timescaledb-test >/dev/null 2>&1 || true' EXIT

ready=0
for _ in $(seq 1 30); do
  if docker exec "$cid" pg_isready -q -U postgres >/dev/null 2>&1; then ready=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "FAIL: postgres did not become ready"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

# This is the real functional check: CREATE EXTENSION exercises the compiled
# .so (shared_preload_libraries alone only proves the library loads at
# postmaster start, not that the SQL-level extension install path works).
# Two separate -c calls so the CREATE EXTENSION status tag never lands in the
# same output as the SELECT below (a single multi-statement -c prints both,
# and piping into `tr -d '[:space:]'` then glues "CREATE EXTENSION" onto the
# version string instead of just stripping the newline between them).
docker exec "$cid" psql -U postgres -tAc "CREATE EXTENSION IF NOT EXISTS timescaledb;" >/dev/null \
  || { echo "FAIL: CREATE EXTENSION timescaledb failed"; docker logs "$cid" 2>&1 | tail -30; exit 1; }
out=$(docker exec "$cid" psql -U postgres -tAc \
  "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>&1 | tr -d '[:space:]')
echo "$out" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo "FAIL: timescaledb extension did not report a version, got '$out'"; docker logs "$cid" 2>&1 | tail -30; exit 1; }
echo "timescaledb extension version: $out"

echo "Testing a hypertable can actually be created..."
out=$(docker exec "$cid" psql -U postgres -tAc \
  "CREATE TABLE t(ts timestamptz NOT NULL, v double precision); SELECT create_hypertable('t','ts'); INSERT INTO t VALUES (now(), 1.0); SELECT count(*) FROM t;" \
  2>&1 | tail -1 | tr -d '[:space:]')
[ "$out" = "1" ] || { echo "FAIL: hypertable round-trip returned '$out', expected 1"; docker logs "$cid" 2>&1 | tail -30; exit 1; }
echo "hypertable insert+count -> $out"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "70" ] || { echo "FAIL: expected uid 70 (postgres), got '$uid'"; exit 1; }

echo "Verifying prod restraint: shell is busybox-only, no bash/apk-tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: /bin/sh missing — initdb will break"; exit 1; }
for forbidden in /bin/bash /usr/bin/bash /sbin/apk /usr/bin/apk; do
  docker run --rm --entrypoint "$forbidden" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $forbidden present in prod image"; exit 1; }
done
echo "busybox sh only (as expected)"

echo "All timescaledb tests passed!"
