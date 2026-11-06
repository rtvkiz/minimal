#!/bin/bash
set -euo pipefail

echo "Testing Keycloak starts in dev mode..."
docker run -d --name keycloak-test \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  "$IMAGE" start-dev

READY_BODY=$(mktemp)
READY_ERR=$(mktemp)
READY_CODE=""
DEV_OK=0

for i in $(seq 1 30); do
  if ! docker ps --format '{{.Names}}' | grep -qx keycloak-test; then
    echo "Keycloak container exited before becoming ready"
    docker logs keycloak-test 2>&1 || true
    docker rm keycloak-test 2>/dev/null || true
    rm -f "$READY_BODY" "$READY_ERR"
    exit 1
  fi

  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keycloak-test)
  READY_CODE=$(curl -sS -o "$READY_BODY" -w '%{http_code}' "http://${IP}:9000/health/ready" 2>"$READY_ERR" || true)

  if [ "$READY_CODE" = "200" ]; then
    head -c 200 "$READY_BODY"
    echo ""
    echo "Keycloak is running and healthy (attempt ${i})"
    docker stop keycloak-test && docker rm keycloak-test
    rm -f "$READY_BODY" "$READY_ERR"
    DEV_OK=1
    break
  fi

  sleep 2
done

if [ "$DEV_OK" != 1 ]; then
  echo "Keycloak did not become ready after 60s"
  echo "Last /health/ready HTTP status: ${READY_CODE:-unknown}"
  if [ -s "$READY_BODY" ]; then
    echo "Last readiness response:"
    head -c 500 "$READY_BODY"
    echo ""
  fi
  if [ -s "$READY_ERR" ]; then
    echo "Last curl error:"
    cat "$READY_ERR"
  fi
  echo "Container logs:"
  docker logs keycloak-test 2>&1 || true
  docker stop keycloak-test 2>/dev/null || true
  docker rm keycloak-test 2>/dev/null || true
  rm -f "$READY_BODY" "$READY_ERR"
  exit 1
fi

# REGRESSION GUARD (#1064): start-dev runs on the embedded dev-file database and
# never loads the Quarkus PostgreSQL extension, so it passed while the shipped
# image could not use PostgreSQL at all. The bundled-jar swap for the JDBC
# driver (postgresql) also matched io.quarkus.quarkus-jdbc-postgresql-*.jar and
# overwrote it with the driver, and every --db=postgres build died with
# NoClassDefFoundError PostgreSQLAgroalConnectionConfigurer. Build for postgres,
# then boot against a real server until /health/ready (which includes the
# database check) returns 200.
echo "Testing Keycloak builds for PostgreSQL..."
BUILD_OUT=$(docker run --rm "$IMAGE" build --db=postgres 2>&1) || {
  echo "FAIL: kc.sh build --db=postgres failed"; echo "$BUILD_OUT" | tail -20; exit 1; }
echo "kc.sh build --db=postgres succeeded"

echo "Testing Keycloak starts against PostgreSQL..."
PG_IMAGE="${KEYCLOAK_TEST_PG_IMAGE:-ghcr.io/rtvkiz/minimal-postgres-slim:latest}"
NET=keycloak-test-net
cleanup_pg() {
  docker rm -f keycloak-pg-test keycloak-pg >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
cleanup_pg
trap cleanup_pg EXIT
docker network create "$NET" >/dev/null
docker run -d --name keycloak-pg --network "$NET" --entrypoint /bin/sh "$PG_IMAGE" \
  -c 'initdb -D "$PGDATA" -U keycloak --auth=trust \
      && echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf" \
      && exec postgres -D "$PGDATA" -h 0.0.0.0' >/dev/null

PG_READY=0
for _ in $(seq 1 30); do
  if docker exec keycloak-pg pg_isready -q -U keycloak >/dev/null 2>&1; then PG_READY=1; break; fi
  sleep 1
done
[ "$PG_READY" = 1 ] || { echo "FAIL: postgres sidecar did not become ready"; docker logs keycloak-pg 2>&1 | tail -20; exit 1; }

docker run -d --name keycloak-pg-test --network "$NET" \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://keycloak-pg:5432/postgres \
  -e KC_DB_USERNAME=keycloak \
  -e KC_HEALTH_ENABLED=true \
  -e KC_HTTP_ENABLED=true \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  "$IMAGE" start >/dev/null

PG_CODE=""
for i in $(seq 1 60); do
  if ! docker ps --format '{{.Names}}' | grep -qx keycloak-pg-test; then
    echo "FAIL: Keycloak (postgres) exited before becoming ready"
    docker logs keycloak-pg-test 2>&1 | tail -40
    exit 1
  fi
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keycloak-pg-test)
  PG_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://${IP}:9000/health/ready" || true)
  if [ "$PG_CODE" = "200" ]; then
    echo "Keycloak is running on PostgreSQL and healthy (attempt ${i})"
    echo "✓ Keycloak tests passed"
    exit 0
  fi
  sleep 2
done

echo "FAIL: Keycloak (postgres) did not become ready after 120s (last /health/ready: ${PG_CODE:-unknown})"
docker logs keycloak-pg-test 2>&1 | tail -40
exit 1
