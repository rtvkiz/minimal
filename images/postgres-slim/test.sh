#!/bin/bash
set -euo pipefail
: "${IMAGE:?IMAGE env var required}"

echo "Testing PostgreSQL version..."
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version | grep -qiE 'PostgreSQL\) 18\.' \
  || { echo "FAIL: postgres 18 version string not found"; exit 1; }

echo "Testing psql client..."
docker run --rm --entrypoint /usr/bin/psql "$IMAGE" --version | grep -qiE 'psql .*18\.' \
  || { echo "FAIL: psql 18 version string not found"; exit 1; }

echo "Testing initdb can initialise a fresh PGDATA..."
# REGRESSION GUARD: initdb runs `"postgres" -V` via popen(), which execs /bin/sh.
# A shell-less image fails here with ENOENT, cannot initialise an empty volume,
# and so cannot start on first run. This is why prod carries busybox.
# The previous version of this test wrapped the whole thing in `|| true` and
# treated a dead container as "informational", so it passed while the shipped
# image was broken. Do not reintroduce that.
docker run --rm --tmpfs /pgtest:uid=70,gid=70,mode=0700 \
  --entrypoint /usr/bin/initdb "$IMAGE" -D /pgtest -U postgres --auth=trust 2>&1 \
  | grep -qi 'Success' \
  || { echo "FAIL: initdb could not initialise a data dir (missing /bin/sh?)"; exit 1; }

echo "Testing PostgreSQL starts and serves queries..."
docker rm -f postgres-test >/dev/null 2>&1 || true
cid=$(docker run -d --name postgres-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --entrypoint /bin/sh "$IMAGE" \
  -c 'initdb -D "$PGDATA" -U postgres --auth=trust && exec postgres -D "$PGDATA" -h 0.0.0.0')
trap 'docker rm -f postgres-test >/dev/null 2>&1 || true' EXIT

ready=0
for _ in $(seq 1 30); do
  if docker exec "$cid" pg_isready -q -U postgres >/dev/null 2>&1; then ready=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "FAIL: postgres did not become ready"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

out=$(docker exec "$cid" psql -U postgres -tAc 'SELECT 1;' 2>/dev/null | tr -d '[:space:]')
[ "$out" = "1" ] || { echo "FAIL: query returned '${out:-<none>}', expected 1"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
echo "SELECT 1 -> $out (server accepted a real query)"

echo "Verifying non-root..."
# NOTE: this image runs as the postgres account (uid 70), not the catalog's
# usual nonroot 65532 — postgres refuses to run as a uid that does not own
# PGDATA, and the upstream convention is uid 70.
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

echo "All postgres-slim tests passed!"
