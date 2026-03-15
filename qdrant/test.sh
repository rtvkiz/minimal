#!/bin/bash
set -euo pipefail

echo "Testing Qdrant version..."
docker run --rm --entrypoint /usr/bin/qdrant "$IMAGE" --version

echo "Testing Qdrant starts and serves REST API..."
docker run -d --name qdrant-test "$IMAGE"
sleep 4

if docker ps | grep -q qdrant-test; then
  QDRANT_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' qdrant-test)
  # Health check
  curl -sf "http://${QDRANT_IP}:6333/healthz" | grep -q "healthz check passed"
  # List collections (empty on fresh start)
  curl -sf "http://${QDRANT_IP}:6333/collections" | grep -q '"status":"ok"'
  echo "Qdrant is running and REST API works"
  docker stop qdrant-test && docker rm qdrant-test
else
  echo "Qdrant failed to start"
  docker logs qdrant-test 2>&1 || true
  docker rm qdrant-test 2>/dev/null || true
  exit 1
fi

echo "✓ Qdrant tests passed"
