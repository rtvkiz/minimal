#!/bin/bash
set -euo pipefail

echo "Testing Alertmanager version..."
docker run --rm --entrypoint /usr/bin/alertmanager "$IMAGE" --version

echo "Testing amtool version..."
docker run --rm --entrypoint /usr/bin/amtool "$IMAGE" --version

echo "Testing Alertmanager starts and serves HTTP API..."
docker run -d --name alertmanager-test -p 9093:9093 \
  --entrypoint /usr/bin/alertmanager \
  "$IMAGE" \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/alertmanager \
  --web.listen-address=0.0.0.0:9093
trap 'docker stop alertmanager-test >/dev/null 2>&1; docker rm alertmanager-test >/dev/null 2>&1' EXIT

sleep 4

if ! docker ps | grep -q alertmanager-test; then
  echo "Alertmanager failed to start, logs:"
  docker logs alertmanager-test 2>&1 || true
  exit 1
fi

if curl -sf http://localhost:9093/-/healthy; then
  echo "Alertmanager is running and healthy"
else
  echo "::error::Alertmanager /-/healthy returned non-2xx"
  docker logs alertmanager-test 2>&1 || true
  exit 1
fi

echo "Testing config validation with amtool..."
docker run --rm \
  --entrypoint /usr/bin/amtool \
  "$IMAGE" \
  check-config /etc/alertmanager/alertmanager.yml

echo "✓ Alertmanager tests passed"
