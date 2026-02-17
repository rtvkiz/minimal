#!/bin/bash
set -euo pipefail

echo "Testing MySQL server version..."
docker run --rm "$IMAGE" --version

echo "Testing MySQL client version..."
docker run --rm --entrypoint /usr/bin/mysql "$IMAGE" --version

echo "Testing MySQL initialize..."
# Docker volumes inherit mount point ownership from the image on first use,
# so /var/lib/mysql (uid 65532) in the image means the volume will be writable
docker volume create mysql-test-data >/dev/null
docker run --rm -v mysql-test-data:/var/lib/mysql \
  "$IMAGE" --initialize-insecure 2>&1 | tail -5

echo "Testing MySQL starts..."
docker run -d --name mysql-test -v mysql-test-data:/var/lib/mysql \
  "$IMAGE" --skip-grant-tables
sleep 5

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

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
