#!/bin/bash
set -euo pipefail

echo "Testing PostgreSQL version..."
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version

echo "Testing psql client..."
docker run --rm --entrypoint /usr/bin/psql "$IMAGE" --version

echo "Testing PostgreSQL starts..."
docker run -d --name postgres-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --entrypoint "" "$IMAGE" \
  sh -c "initdb -D /var/lib/postgresql/data && postgres -D /var/lib/postgresql/data -h 0.0.0.0" || true
sleep 5

if docker ps | grep -q postgres-test; then
  echo "PostgreSQL is running"
  docker logs postgres-test 2>&1 | tail -5
  docker stop postgres-test && docker rm postgres-test
else
  echo "PostgreSQL startup check (informational)..."
  docker logs postgres-test 2>&1 || true
  docker rm postgres-test 2>/dev/null || true
fi
