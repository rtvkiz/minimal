#!/bin/bash
set -euo pipefail

echo "Testing MySQL server version..."
docker run --rm --entrypoint /usr/bin/mysqld "$IMAGE" --version

echo "Testing MySQL client version..."
docker run --rm --entrypoint /usr/bin/mysql "$IMAGE" --version

echo "Testing MySQL auto-init and startup..."
docker volume create mysql-test-data >/dev/null
docker run -d --name mysql-test -v mysql-test-data:/var/lib/mysql "$IMAGE"
sleep 10

if docker ps | grep -q mysql-test; then
  echo "MySQL is running"
  docker logs mysql-test 2>&1 | tail -10
  docker stop mysql-test && docker rm mysql-test
else
  echo "MySQL failed to start, checking logs..."
  docker logs mysql-test 2>&1 || true
  docker rm mysql-test 2>/dev/null || true
  docker volume rm mysql-test-data 2>/dev/null || true
  exit 1
fi

docker volume rm mysql-test-data 2>/dev/null || true
