#!/bin/bash
set -euo pipefail

echo "Testing Prometheus version..."
docker run --rm --entrypoint /usr/bin/prometheus "$IMAGE" --version

echo "Testing promtool version..."
docker run --rm --entrypoint /usr/bin/promtool "$IMAGE" --version

echo "Testing Prometheus starts and serves HTTP API..."
docker run -d --name prometheus-test \
  --entrypoint /usr/bin/prometheus \
  "$IMAGE" \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.listen-address=0.0.0.0:9090
sleep 4

if docker ps | grep -q prometheus-test; then
  docker exec prometheus-test /usr/bin/promtool check healthy --http.config.file="" 2>/dev/null || \
    curl -sf http://$(docker inspect -f '{{.NetworkSettings.IPAddress}}' prometheus-test):9090/-/healthy
  echo "Prometheus is running and healthy"
  docker stop prometheus-test && docker rm prometheus-test
else
  echo "Prometheus failed to start, checking logs..."
  docker logs prometheus-test 2>&1 || true
  docker rm prometheus-test 2>/dev/null || true
  exit 1
fi

echo "Testing config validation with promtool..."
docker run --rm \
  --entrypoint /usr/bin/promtool \
  "$IMAGE" \
  check config /etc/prometheus/prometheus.yml

echo "✓ Prometheus tests passed"
