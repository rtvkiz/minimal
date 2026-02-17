#!/bin/bash
set -euo pipefail

echo "Testing MySQL server version..."
docker run --rm "$IMAGE" --version

echo "Testing MySQL client version..."
docker run --rm --entrypoint /usr/bin/mysql "$IMAGE" --version

echo "Testing MySQL initialize..."
docker run --rm --user root "$IMAGE" \
  --initialize-insecure --datadir=/tmp/mysql-test 2>&1 | tail -5

echo "Testing MySQL starts..."
docker run -d --name mysql-test \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=1 \
  "$IMAGE" --datadir=/tmp/mysql-data --skip-grant-tables
sleep 5

if docker ps | grep -q mysql-test; then
  echo "MySQL is running"
  docker logs mysql-test 2>&1 | tail -10
  docker stop mysql-test && docker rm mysql-test
else
  echo "MySQL failed to start, checking logs..."
  docker logs mysql-test 2>&1 || true
  docker rm mysql-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
