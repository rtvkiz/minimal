#!/bin/bash
set -euo pipefail

echo "Testing Redis starts..."
docker run -d --name redis-test "$IMAGE"
sleep 2

if docker ps | grep -q redis-test; then
  echo "Redis is running"
  docker logs redis-test
  docker stop redis-test && docker rm redis-test
else
  echo "Redis failed to start, checking logs..."
  docker logs redis-test 2>&1 || true
  docker rm redis-test 2>/dev/null || true
  exit 1
fi

echo "Testing Redis CLI..."
docker network create redis-test-net 2>/dev/null || true
docker run -d --network redis-test-net --name redis-cli-test "$IMAGE"
sleep 2
docker run --rm --network redis-test-net --entrypoint /usr/bin/redis-cli "$IMAGE" -h redis-cli-test PING
docker stop redis-cli-test && docker rm redis-cli-test
docker network rm redis-test-net 2>/dev/null || true
