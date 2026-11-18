#!/bin/bash
# Smoke test for minimal-adminer (prod).
# The core check is a real round trip: log in to a PostgreSQL server through
# Adminer's web UI and read a query result back out of the page.
set -eu
: "${IMAGE:?IMAGE env var required}"
PG_IMAGE="${PG_IMAGE:-ghcr.io/rtvkiz/minimal-postgres-slim:latest}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
port=18081
net="minimal-adminer-smoke-$$"
cleanup() {
  docker rm -f "adminer-web-$$" "adminer-pg-$$" >/dev/null 2>&1 || true
  docker network rm "$net" >/dev/null 2>&1 || true
  rm -f "${jar:-}"
}
trap cleanup EXIT

echo "Testing the PHP extensions Adminer's drivers need are loaded..."
mods=$(docker run --rm --entrypoint /usr/bin/php "$IMAGE" -m 2>&1)
for m in mysqli mysqlnd pgsql pdo_sqlite session openssl mbstring; do
  echo "$mods" | grep -qx "$m" || { echo "FAIL: PHP extension $m not loaded"; exit 1; }
done

echo "Starting PostgreSQL (password auth, reachable on a private network)..."
# A fresh random password per run, passed in through the environment: the
# database only lives for this test, and nothing credential-shaped is committed.
pg_pw=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
docker network create "$net" >/dev/null
docker run -d --name "adminer-pg-$$" --network "$net" -e "SMOKE_PG_PW=$pg_pw" --entrypoint /bin/sh "$PG_IMAGE" -c \
  'printf "%s\n" "$SMOKE_PG_PW" > /tmp/pw && initdb -D "$PGDATA" -U postgres --auth=scram-sha-256 --pwfile=/tmp/pw >/dev/null \
   && echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf" \
   && exec postgres -D "$PGDATA" -h 0.0.0.0' >/dev/null
ready=0
for _ in $(seq 1 40); do
  docker exec "adminer-pg-$$" pg_isready -q -h 127.0.0.1 -U postgres >/dev/null 2>&1 && { ready=1; break; }
  sleep 1
done
[ "$ready" = 1 ] || { echo "FAIL: postgres did not become ready"; docker logs "adminer-pg-$$" 2>&1 | tail -20; exit 1; }

echo "Starting Adminer..."
docker run -d --name "adminer-web-$$" --network "$net" -p "127.0.0.1:${port}:8080" "$IMAGE" >/dev/null
B="http://127.0.0.1:${port}"
up=0
for _ in $(seq 1 30); do curl -sf -o /dev/null "$B/" && { up=1; break; }; sleep 1; done
[ "$up" = 1 ] || { echo "FAIL: Adminer did not serve HTTP"; docker logs "adminer-web-$$" 2>&1 | tail -20; exit 1; }

jar=$(mktemp)
tok() { grep -oE "name=.token. value=.[^\"']+" | head -1 | sed -E "s/.*value=.//"; }

echo "Testing the login page reports version $EXPECTED..."
page=$(curl -s -c "$jar" -b "$jar" "$B/")
echo "$page" | grep -q "$EXPECTED" || { echo "FAIL: login page does not show Adminer $EXPECTED"; exit 1; }
t=$(echo "$page" | tok)
[ -n "$t" ] || { echo "FAIL: no CSRF token on the login form"; exit 1; }

echo "Testing login to PostgreSQL through Adminer..."
code=$(curl -s -c "$jar" -b "$jar" -o /dev/null -w '%{http_code}' -X POST "$B/" \
  --data-urlencode "auth[driver]=pgsql" --data-urlencode "auth[server]=adminer-pg-$$" \
  --data-urlencode "auth[username]=postgres" --data-urlencode "auth[password]=${pg_pw}" \
  --data-urlencode "auth[db]=postgres" --data-urlencode "token=$t")
[ "$code" = 303 ] || { echo "FAIL: login returned HTTP $code, expected a 303 redirect"; exit 1; }

echo "Testing a SQL query round trip..."
Q="$B/?pgsql=adminer-pg-$$&username=postgres&db=postgres&ns=public&sql="
t2=$(curl -s -c "$jar" -b "$jar" "$Q" | tok)
out=$(curl -s -c "$jar" -b "$jar" "$Q" -F "query=SELECT 'adminer-roundtrip-' || current_setting('server_version_num')" \
  -F "limit=" -F "token=$t2")
echo "$out" | grep -qE 'adminer-roundtrip-[0-9]{5,}' \
  || { echo "FAIL: query result not found in the page"; echo "$out" | sed 's/<[^>]*>/ /g' | tr -s ' \n' | grep -oiE 'error[^.]{0,160}' | head -3; exit 1; }
echo "  $(echo "$out" | grep -oE 'adminer-roundtrip-[0-9]+' | head -1)"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found"; exit 1; } || echo "No apk (as expected)"

echo "All adminer tests passed!"
