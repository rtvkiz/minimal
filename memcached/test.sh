#!/bin/bash
set -euo pipefail

echo "Testing Memcached version..."
docker run --rm "$IMAGE" -V

echo "Testing Memcached starts..."
docker run -d --name memcached-test "$IMAGE" -u memcached
sleep 2

if docker ps | grep -q memcached-test; then
  echo "Memcached is running"
  docker logs memcached-test
  docker stop memcached-test && docker rm memcached-test
else
  echo "Memcached failed to start, checking logs..."
  docker logs memcached-test 2>&1 || true
  docker rm memcached-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
