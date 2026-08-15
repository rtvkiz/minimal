#!/bin/bash
set -euo pipefail

cleanup() { docker rm -f vaultwarden-dev-test >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing vaultwarden version (parity with prod)..."
ver=$(docker run --rm --entrypoint /usr/bin/vaultwarden "$IMAGE" --version)
echo "$ver" | grep -qi "vaultwarden" || { echo "$ver"; exit 1; }

echo "Testing dev tooling is present..."
for tool in /bin/sh /bin/bash /usr/bin/curl /usr/bin/jq /usr/bin/sqlite3; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x $tool" \
    || { echo "missing dev tool: $tool"; exit 1; }
done

echo "Testing the web vault assets are bundled..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /usr/share/vaultwarden/web-vault/index.html"

echo "Testing Vaultwarden starts and serves its API..."
docker run -d --name vaultwarden-dev-test "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 30); do
  sleep 2
  docker ps --format '{{.Names}}' | grep -q '^vaultwarden-dev-test$' || break
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vaultwarden-dev-test)
  if curl -sf "http://${IP}:8080/alive" >/dev/null 2>&1; then ready=1; break; fi
done

if [ "$ready" -ne 1 ]; then
  echo "Vaultwarden (dev) did not become ready"
  docker logs vaultwarden-dev-test 2>&1 | tail -30 || true
  exit 1
fi

# sqlite3 is in this image specifically to inspect the database the prod image
# links statically — check it can actually open what the server created.
tables=$(docker exec vaultwarden-dev-test /bin/sh -c \
  "test -f /data/db.sqlite3 && sqlite3 /data/db.sqlite3 '.tables'")
echo "$tables" | grep -qi "users" \
  || { echo "sqlite3 could not read the vaultwarden database: $tables"; exit 1; }

echo "✓ All vaultwarden-dev smoke tests passed"
