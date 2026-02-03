#!/bin/bash
set -euo pipefail

echo "Testing Nginx starts..."
docker run -d --name nginx-test "$IMAGE"
sleep 2

if docker ps | grep -q nginx-test; then
  echo "Nginx is running"
  docker logs nginx-test
  docker stop nginx-test && docker rm nginx-test
else
  echo "Nginx failed to start, checking logs..."
  docker logs nginx-test 2>&1 || true
  docker rm nginx-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
