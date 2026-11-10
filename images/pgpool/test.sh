#!/bin/bash
# Smoke test for minimal-pgpool (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

container="minimal-pgpool-test-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing pgpool version..."
ver=$(docker run --rm --entrypoint /usr/bin/pgpool "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'pgpool-II version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing admin tools are present..."
# pg_md5 hashes passwords for pool_passwd; pcp_node_info talks to the PCP port.
md5=$(docker run --rm --entrypoint /usr/bin/pg_md5 "$IMAGE" secret 2>&1)
[ "$md5" = "5ebe2294ecd0e0f08eab7690d2a6ee69" ] || { echo "FAIL: pg_md5 returned '$md5'"; exit 1; }
docker run --rm --entrypoint /usr/bin/pcp_node_info "$IMAGE" --help >/dev/null 2>&1 \
  || { echo "FAIL: pcp_node_info missing or broken"; exit 1; }

echo "Testing a real query through pgpool to PostgreSQL..."
# End to end: a PostgreSQL sidecar named `postgres` (the default config's
# backend), pgpool in front of it, and psql connecting to pgpool on :9999.
PG_IMAGE="${PGPOOL_TEST_PG_IMAGE:-ghcr.io/rtvkiz/minimal-postgres-slim:latest}"
net="pgpool-test-net-$$"
cleanup() {
  docker rm -f "$container" "pgpool-pg-$$" >/dev/null 2>&1 || true
  docker network rm "$net" >/dev/null 2>&1 || true
}
docker network create "$net" >/dev/null
docker run -d --name "pgpool-pg-$$" --network "$net" --network-alias postgres --entrypoint /bin/sh "$PG_IMAGE" \
  -c 'initdb -D "$PGDATA" -U postgres --auth=trust \
      && echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf" \
      && exec postgres -D "$PGDATA" -h 0.0.0.0' >/dev/null
pg_ready=false
for _ in $(seq 1 30); do
  if docker exec "pgpool-pg-$$" pg_isready -q -U postgres >/dev/null 2>&1; then pg_ready=true; break; fi
  sleep 1
done
[ "$pg_ready" = true ] || { echo "FAIL: postgres sidecar not ready"; docker logs "pgpool-pg-$$" 2>&1 | tail -20; exit 1; }

docker run -d --name "$container" --network "$net" "$IMAGE" >/dev/null
result=""
for _ in $(seq 1 30); do
  result=$(docker run --rm --network "$net" --entrypoint psql "$PG_IMAGE" \
    -h "$container" -p 9999 -U postgres -tAc "select 'through-pgpool:' || 40 + 2" 2>/dev/null || true)
  [ "$result" = "through-pgpool:42" ] && break
  [ -n "$(docker ps -q --filter name="$container")" ] || break
  sleep 1
done
[ "$result" = "through-pgpool:42" ] || { echo "FAIL: query through pgpool returned '$result'"; docker logs "$container" 2>&1 | tail -30; exit 1; }
show=$(docker run --rm --network "$net" --entrypoint psql "$PG_IMAGE" -h "$container" -p 9999 -U postgres -tAc "show pool_nodes" 2>&1 || true)
echo "$show" | grep -q "postgres|5432|up" || { echo "FAIL: pool_nodes does not show the backend up: $show"; exit 1; }
echo "✓ query answered through pgpool; backend reported up"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All pgpool tests passed!"
