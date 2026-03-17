#!/bin/bash
set -euo pipefail

echo "Testing Jaeger version..."
docker run --rm --entrypoint /usr/bin/jaeger "$IMAGE" --version

echo "Testing Jaeger starts and serves UI..."
docker run -d --name jaeger-test "$IMAGE"

JAEGER_IP=""
for i in $(seq 1 15); do
  sleep 2
  if ! docker ps | grep -q jaeger-test; then
    echo "Jaeger container exited early"
    docker logs jaeger-test 2>&1 || true
    docker rm jaeger-test 2>/dev/null || true
    exit 1
  fi
  JAEGER_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' jaeger-test)
  if curl -sf "http://${JAEGER_IP}:16686/" > /dev/null 2>&1; then
    echo "Jaeger Query UI is accessible (attempt ${i})"
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "Jaeger UI did not become ready after 30s"
    docker logs jaeger-test 2>&1 || true
    docker stop jaeger-test && docker rm jaeger-test
    exit 1
  fi
done

if docker ps | grep -q jaeger-test; then
  echo "Jaeger is running and UI is accessible"
  docker stop jaeger-test && docker rm jaeger-test
else
  echo "Jaeger failed to start"
  docker logs jaeger-test 2>&1 || true
  docker rm jaeger-test 2>/dev/null || true
  exit 1
fi

echo "✓ Jaeger tests passed"
