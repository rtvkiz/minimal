#!/bin/bash
set -euo pipefail

echo "Testing Valkey starts..."
docker run -d --name valkey-test "$IMAGE"
sleep 2

if docker ps | grep -q valkey-test; then
  echo "Valkey is running"
  docker logs valkey-test
  docker stop valkey-test && docker rm valkey-test
else
  echo "Valkey failed to start, checking logs..."
  docker logs valkey-test 2>&1 || true
  docker rm valkey-test 2>/dev/null || true
  exit 1
fi

echo "Testing Valkey CLI PING..."
docker network create valkey-test-net 2>/dev/null || true
docker run -d --network valkey-test-net --name valkey-srv "$IMAGE"
sleep 2
docker run --rm --network valkey-test-net --entrypoint /usr/bin/valkey-cli "$IMAGE" -h valkey-srv PING
docker stop valkey-srv && docker rm valkey-srv
docker network rm valkey-test-net 2>/dev/null || true

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
