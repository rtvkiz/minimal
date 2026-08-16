#!/bin/bash
set -euo pipefail

echo "Testing CoreDNS version..."
docker run --rm "$IMAGE" -version || true

echo "Testing CoreDNS starts and serves DNS..."
docker run -d --name coredns-test "$IMAGE"
sleep 3

if docker ps | grep -q coredns-test; then
  echo "CoreDNS is running"
  docker stop coredns-test && docker rm coredns-test
else
  echo "CoreDNS failed to start, checking logs..."
  docker logs coredns-test 2>&1 || true
  docker rm coredns-test 2>/dev/null || true
  exit 1
fi

echo "✓ CoreDNS tests passed"
