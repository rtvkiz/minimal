#!/bin/bash
set -euo pipefail

echo "Testing Jaeger version..."
docker run --rm --entrypoint /usr/bin/jaeger "$IMAGE" --version

echo "Testing Jaeger starts and serves UI + health check..."
docker run -d --name jaeger-test "$IMAGE"
sleep 8

if docker ps | grep -q jaeger-test; then
  JAEGER_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' jaeger-test)
  # Health check endpoint
  curl -sf "http://${JAEGER_IP}:13133/" | grep -qi "ok\|healthy\|ready" || \
    curl -sf "http://${JAEGER_IP}:13133/health/status"
  # Query UI endpoint
  curl -sf "http://${JAEGER_IP}:16686/" > /dev/null
  echo "Jaeger is running and UI is accessible"
  docker stop jaeger-test && docker rm jaeger-test
else
  echo "Jaeger failed to start"
  docker logs jaeger-test 2>&1 || true
  docker rm jaeger-test 2>/dev/null || true
  exit 1
fi

echo "✓ Jaeger tests passed"
