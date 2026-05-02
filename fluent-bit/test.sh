#!/bin/bash
set -euo pipefail

echo "Testing Fluent Bit version..."
docker run --rm "$IMAGE" --version

echo "Testing Fluent Bit starts..."
docker run -d --name fluentbit-test "$IMAGE"
sleep 3

if docker ps | grep -q fluentbit-test; then
  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' fluentbit-test)
  curl -sf "http://${IP}:2020/api/v1/health" | head -c 200
  echo ""
  echo "Fluent Bit is running and healthy"
  docker stop fluentbit-test && docker rm fluentbit-test
else
  echo "Fluent Bit failed to start, checking logs..."
  docker logs fluentbit-test 2>&1 || true
  docker rm fluentbit-test 2>/dev/null || true
  exit 1
fi

echo "✓ Fluent Bit tests passed"
