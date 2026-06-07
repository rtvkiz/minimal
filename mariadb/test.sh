#!/bin/bash
set -euo pipefail

echo "Testing MariaDB version..."
docker run --rm --entrypoint /usr/bin/mariadbd "$IMAGE" --version
docker run --rm --entrypoint /usr/bin/mariadb "$IMAGE" --version

echo "Testing MariaDB auto-init, startup, CRUD, and restart persistence..."
docker run -d --name mariadb-test \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=1 \
  "$IMAGE"

cleanup() {
  echo "--- container logs ---"
  docker logs mariadb-test 2>&1 | tail -30 || true
  docker rm -f mariadb-test 2>/dev/null || true
}
trap cleanup EXIT

# Wait up to 60s for mariadbd to accept connections via socket.
# mariadb-install-db on first boot can take ~10–20s.
ready=0
for i in $(seq 1 60); do
  if docker exec --user 0 mariadb-test mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "MariaDB never became ready"
  exit 1
fi
echo "✓ Server started and accepting connections"

# CRUD round-trip — exercises plugin dir (InnoDB) + errmsg + client socket
docker exec --user 0 mariadb-test mariadb -uroot -e "
  CREATE DATABASE smoke;
  USE smoke;
  CREATE TABLE x (id INT PRIMARY KEY, label VARCHAR(16));
  INSERT INTO x VALUES (1, 'one'), (2, 'two');
  SELECT COUNT(*) FROM x;
" | grep -q "^2$"
echo "✓ CRUD round-trip succeeded"

# Plugin directory wired correctly
docker exec --user 0 mariadb-test mariadb -uroot -e "SHOW PLUGINS" | grep -q InnoDB
echo "✓ InnoDB plugin loaded"

# mysqld/mysql compat symlinks must work
docker exec mariadb-test sh -c 'test -L /usr/bin/mysqld && test -L /usr/bin/mysql'
docker exec mariadb-test mysqld --version >/dev/null
echo "✓ mysqld/mysql compat symlinks work"

# Restart — exercises the *already-initialized* boot path (ibdata1 exists)
docker restart mariadb-test >/dev/null
ready=0
for i in $(seq 1 60); do
  if docker exec --user 0 mariadb-test mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "MariaDB did not come back up after restart"
  exit 1
fi
docker exec --user 0 mariadb-test mariadb -uroot -e "SELECT label FROM smoke.x WHERE id=1" | grep -q one
echo "✓ Persistence across restart confirmed"

# Allowlist sanity: confirm we didn't drag mariadb-test / mytop / perl
# scripts back in by accident.
if docker exec mariadb-test sh -c 'command -v mariadb-test 2>/dev/null'; then
  echo "WARNING: mariadb-test binary present in image — allowlist trim regressed"
  exit 1
fi
if docker exec mariadb-test sh -c 'command -v mytop 2>/dev/null'; then
  echo "WARNING: mytop (perl script) present — drags cmd:perl into deps"
  exit 1
fi
if docker exec mariadb-test sh -c 'command -v mariabackup 2>/dev/null'; then
  echo "WARNING: mariabackup present — should be in a separate backup image"
  exit 1
fi
echo "✓ Allowlist trim is holding"

docker stop mariadb-test >/dev/null

echo "✓ MariaDB tests passed"
