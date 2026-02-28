#!/bin/bash
set -euo pipefail

echo "Testing NATS Server version..."
docker run --rm --entrypoint /usr/bin/nats-server "$IMAGE" --version

echo "Testing NATS Server starts..."
docker run -d --name nats-test "$IMAGE"
sleep 2

if docker ps | grep -q nats-test; then
  echo "NATS Server is running"
  docker logs nats-test
  docker stop nats-test && docker rm nats-test
else
  echo "NATS Server failed to start, checking logs..."
  docker logs nats-test 2>&1 || true
  docker rm nats-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
