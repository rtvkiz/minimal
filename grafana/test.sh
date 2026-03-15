#!/bin/bash
set -euo pipefail

echo "Testing Grafana version..."
docker run --rm --entrypoint /usr/sbin/grafana "$IMAGE" --version

echo "Testing Grafana server starts and serves HTTP..."
docker run -d --name grafana-test \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  "$IMAGE"
sleep 6

if docker ps | grep -q grafana-test; then
  GRAFANA_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' grafana-test)
  curl -sf "http://${GRAFANA_IP}:3000/api/health" | grep -q '"database":"ok"'
  echo "Grafana is running and healthy"
  docker stop grafana-test && docker rm grafana-test
else
  echo "Grafana failed to start, checking logs..."
  docker logs grafana-test 2>&1 || true
  docker rm grafana-test 2>/dev/null || true
  exit 1
fi

echo "✓ Grafana tests passed"
