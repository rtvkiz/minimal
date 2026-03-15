#!/bin/bash
set -euo pipefail

echo "Testing VictoriaMetrics version..."
docker run --rm --entrypoint /usr/bin/victoria-metrics "$IMAGE" --version

echo "Testing VictoriaMetrics starts and serves HTTP..."
docker run -d --name vm-test "$IMAGE"
sleep 3

if docker ps | grep -q vm-test; then
  VM_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' vm-test)
  # Health check via metrics endpoint
  curl -sf "http://${VM_IP}:8428/health" | grep -q "OK"
  # Check Prometheus-compatible /api/v1/query endpoint
  curl -sf "http://${VM_IP}:8428/api/v1/query?query=up" | grep -q '"status":"success"'
  echo "VictoriaMetrics is running and Prometheus API works"
  docker stop vm-test && docker rm vm-test
else
  echo "VictoriaMetrics failed to start"
  docker logs vm-test 2>&1 || true
  docker rm vm-test 2>/dev/null || true
  exit 1
fi

echo "✓ VictoriaMetrics tests passed"
