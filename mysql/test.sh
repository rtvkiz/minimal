#!/bin/bash
set -euo pipefail

echo "Testing MySQL server version..."
docker run --rm --entrypoint /usr/bin/mysqld "$IMAGE" --version

echo "Testing MySQL client version..."
docker run --rm --entrypoint /usr/bin/mysql "$IMAGE" --version

echo "Testing MySQL auto-init, startup, CRUD, and restart persistence..."
docker volume create mysql-test-data >/dev/null
docker run -d --name mysql-test -v mysql-test-data:/var/lib/mysql "$IMAGE"

cleanup() {
  echo "--- container logs ---"
  docker logs mysql-test 2>&1 | tail -30 || true
  docker rm -f mysql-test 2>/dev/null || true
  docker volume rm mysql-test-data 2>/dev/null || true
}
trap cleanup EXIT

# Wait up to 60s for mysqld to accept connections via socket.
# --initialize-insecure on first boot can take ~10–20s.
ready=0
for i in $(seq 1 60); do
  if docker exec mysql-test mysql -uroot -e "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "MySQL never became ready"
  exit 1
fi
echo "✓ Server started and accepting connections"

# CRUD round-trip — exercises plugin dir (InnoDB) + errmsg.sys + client socket
docker exec mysql-test mysql -uroot -e "
  CREATE DATABASE smoke;
  USE smoke;
  CREATE TABLE x (id INT PRIMARY KEY, label VARCHAR(16));
  INSERT INTO x VALUES (1, 'one'), (2, 'two');
  SELECT COUNT(*) FROM x;
" | grep -q "^2$"
echo "✓ CRUD round-trip succeeded"

# Plugin directory wired correctly
docker exec mysql-test mysql -uroot -e "SHOW PLUGINS" | grep -q InnoDB
echo "✓ InnoDB plugin loaded"

# Restart — exercises the *already-initialized* boot path (ibdata1 exists)
docker restart mysql-test >/dev/null
ready=0
for i in $(seq 1 60); do
  if docker exec mysql-test mysql -uroot -e "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "MySQL did not come back up after restart"
  exit 1
fi
docker exec mysql-test mysql -uroot -e "SELECT label FROM smoke.x WHERE id=1" | grep -q one
echo "✓ Persistence across restart confirmed"

# Allowlist sanity: confirm we didn't drag mysqltest / mysqlxtest / perl scripts
# back in by accident.
if docker exec mysql-test sh -c 'command -v mysqltest 2>/dev/null'; then
  echo "WARNING: mysqltest binary present in image — allowlist trim regressed"
  exit 1
fi
if docker exec mysql-test sh -c 'command -v mysqldumpslow 2>/dev/null'; then
  echo "WARNING: mysqldumpslow (perl script) present — drags cmd:perl into deps"
  exit 1
fi
echo "✓ Allowlist trim is holding"

# Clean shutdown
docker stop mysql-test >/dev/null

echo "✓ MySQL tests passed"
