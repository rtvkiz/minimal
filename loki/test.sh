#!/bin/bash
set -euo pipefail

echo "Testing Loki version..."
docker run --rm "$IMAGE" -version

echo "Testing Loki starts..."
docker run -d --name loki-test "$IMAGE"
sleep 4

if docker ps | grep -q loki-test; then
  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' loki-test)
  curl -sf "http://${IP}:3100/ready" | head -c 200
  echo ""
  echo "Loki is running and ready"
  docker stop loki-test && docker rm loki-test
else
  echo "Loki failed to start, checking logs..."
  docker logs loki-test 2>&1 || true
  docker rm loki-test 2>/dev/null || true
  exit 1
fi

echo "✓ Loki tests passed"
