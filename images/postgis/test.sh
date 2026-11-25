#!/bin/bash
set -euo pipefail
: "${IMAGE:?IMAGE env var required}"

# The PostgreSQL major is whatever the apko config pins. update-wolfi-packages.yml
# moves that pin on a new major, so read it rather than hardcode a number the
# bot does not know to rewrite.
PG_MAJOR=$(grep -oE '^[[:space:]]*- postgresql-[0-9]+$' "$(dirname "$0")/apko/postgis.yaml" | grep -oE '[0-9]+$')
: "${PG_MAJOR:?could not read the postgresql-N pin from apko/postgis.yaml}"

echo "Testing PostgreSQL version..."
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version | grep -qiE "PostgreSQL\\) ${PG_MAJOR}\\." \
  || { echo "FAIL: postgres ${PG_MAJOR} version string not found"; exit 1; }

echo "Testing psql client..."
docker run --rm --entrypoint /usr/bin/psql "$IMAGE" --version | grep -qiE "psql .*${PG_MAJOR}\\." \
  || { echo "FAIL: psql ${PG_MAJOR} version string not found"; exit 1; }

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
docker rm -f postgis-test >/dev/null 2>&1 || true
cid=$(docker run -d --name postgis-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --entrypoint /bin/sh "$IMAGE" \
  -c 'initdb -D "$PGDATA" -U postgres --auth=trust && exec postgres -D "$PGDATA" -h 0.0.0.0')
trap 'docker rm -f postgis-test >/dev/null 2>&1 || true' EXIT

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

echo "Testing CREATE EXTENSION postgis + postgis_raster and real spatial queries..."
q() { docker exec "$cid" psql -U postgres -v ON_ERROR_STOP=1 -tAc "$1" 2>&1; }
q 'CREATE EXTENSION postgis; CREATE EXTENSION postgis_raster;' >/dev/null \
  || { echo "FAIL: CREATE EXTENSION: $(q 'CREATE EXTENSION IF NOT EXISTS postgis;')"; exit 1; }
v=$(q 'SELECT postgis_full_version();')
for lib in GEOS PROJ GDAL; do
  echo "$v" | grep -q "$lib=" || { echo "FAIL: PostGIS built without $lib: $v"; exit 1; }
done
# GEOS: geometry predicates + area
out=$(q "SELECT ST_Area(ST_GeomFromText('POLYGON((0 0,10 0,10 10,0 10,0 0))'));")
[ "$out" = "100" ] || { echo "FAIL: ST_Area returned '$out'"; exit 1; }
# PROJ: a real CRS transform (WGS84 -> Web Mercator) needs proj.db to load
out=$(q "SELECT round(ST_X(ST_Transform(ST_SetSRID(ST_MakePoint(1,0),4326),3857)));")
[ "$out" = "111319" ] || { echo "FAIL: ST_Transform returned '$out' (proj.db missing?)"; exit 1; }
# GDAL: build a raster and read a pixel back
out=$(q "SELECT ST_Value(ST_AddBand(ST_MakeEmptyRaster(2,2,0,0,1),'8BUI'::text,7),1,1);")
[ "$out" = "7" ] || { echo "FAIL: raster ST_Value returned '$out'"; exit 1; }
echo "postgis extension, GEOS, PROJ and GDAL all work"

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
docker run --rm --entrypoint /usr/bin/perl "$IMAGE" -e 'print "perl-ok\n"' 2>/dev/null | grep -q perl-ok \
  || { echo "FAIL: perl missing (postgis-${PG_MAJOR} depends on it)"; exit 1; }

echo "All postgis tests passed!"
