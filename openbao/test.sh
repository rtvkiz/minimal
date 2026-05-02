#!/bin/bash
set -euo pipefail

echo "Testing OpenBao version..."
docker run --rm --entrypoint /usr/bin/bao "$IMAGE" version

echo "Testing OpenBao starts in dev mode..."
docker run -d --name openbao-test \
  --entrypoint /usr/bin/bao \
  "$IMAGE" \
  server -dev -dev-listen-address=0.0.0.0:8200
sleep 4

if docker ps | grep -q openbao-test; then
  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' openbao-test)
  curl -sf "http://${IP}:8200/v1/sys/health" | head -c 200
  echo ""
  echo "OpenBao is running and healthy"
  docker stop openbao-test && docker rm openbao-test
else
  echo "OpenBao failed to start, checking logs..."
  docker logs openbao-test 2>&1 || true
  docker rm openbao-test 2>/dev/null || true
  exit 1
fi

echo "✓ OpenBao tests passed"
