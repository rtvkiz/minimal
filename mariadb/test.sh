#!/bin/bash
set -euo pipefail

echo "Testing MariaDB version..."
docker run --rm --entrypoint /usr/bin/mariadbd "$IMAGE" --version
docker run --rm --entrypoint /usr/bin/mariadb "$IMAGE" --version

echo "Testing MariaDB starts..."
docker run -d --name mariadb-test \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=1 \
  "$IMAGE"
sleep 6

if docker ps | grep -q mariadb-test; then
  echo "MariaDB is running"
  docker logs mariadb-test | tail -5
  docker stop mariadb-test && docker rm mariadb-test
else
  echo "MariaDB failed to start, checking logs..."
  docker logs mariadb-test 2>&1 || true
  docker rm mariadb-test 2>/dev/null || true
  exit 1
fi

echo "✓ MariaDB tests passed"
