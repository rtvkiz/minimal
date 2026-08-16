#!/bin/bash
set -euo pipefail

echo "Testing registry version..."
docker run --rm --entrypoint /usr/bin/registry "$IMAGE" --version

echo "Testing registry server starts..."
docker run -d --name registry-test \
  -p 15000:5000 \
  "$IMAGE"
sleep 5

if docker ps | grep -q registry-test; then
  echo "registry container is running"
  docker logs registry-test

  echo "Checking /v2/ endpoint at :15000..."
  if curl -sf --retry 5 --retry-delay 2 http://localhost:15000/v2/ | grep -q '{}'; then
    echo "registry /v2/ endpoint OK"
  else
    echo "FAIL: registry /v2/ endpoint check failed"
    docker logs registry-test
    docker stop registry-test && docker rm registry-test
    exit 1
  fi

  docker stop registry-test && docker rm registry-test
else
  echo "registry failed to start, checking logs..."
  docker logs registry-test 2>&1 || true
  docker rm registry-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All registry tests passed!"
