#!/bin/bash
set -euo pipefail

echo "Testing OTel Collector version..."
docker run --rm --entrypoint /usr/bin/otelcol "$IMAGE" --version

echo "Testing OTel Collector config validation..."
docker run --rm --entrypoint /usr/bin/otelcol "$IMAGE" \
  validate --config=/etc/otelcol/config.yaml

echo "Testing OTel Collector starts and serves zpages..."
docker run -d --name otelcol-test "$IMAGE"
sleep 3

if docker ps | grep -q otelcol-test; then
  OTEL_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' otelcol-test)
  curl -sf "http://${OTEL_IP}:55679/debug/servicez" > /dev/null
  echo "OTel Collector is running and zpages is accessible"
  docker stop otelcol-test && docker rm otelcol-test
else
  echo "OTel Collector failed to start"
  docker logs otelcol-test 2>&1 || true
  docker rm otelcol-test 2>/dev/null || true
  exit 1
fi

echo "✓ OTel Collector tests passed"
