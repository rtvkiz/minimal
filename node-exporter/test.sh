#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing node_exporter version..."
docker run --rm --entrypoint /usr/bin/node_exporter "$IMAGE" --version 2>&1 | grep -qiE 'node_exporter.*version [0-9]'

echo "Testing node_exporter help..."
docker run --rm --entrypoint /usr/bin/node_exporter "$IMAGE" --help 2>&1 | grep -qiE 'web.listen-address|collector'

echo "Testing node_exporter starts and serves /metrics..."
docker run -d --name node-exporter-test \
  -p 19100:9100 \
  "$IMAGE" --web.listen-address=0.0.0.0:9100
sleep 3

if docker ps | grep -q node-exporter-test; then
  echo "node_exporter container is running"
  docker logs node-exporter-test 2>&1 | tail -5

  echo "Checking /metrics at :19100 exposes node_ series..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://localhost:19100/metrics 2>/dev/null | grep -q '^node_'; then
      echo "node_exporter /metrics OK (attempt $i)"
      break
    fi
    if [ "$i" = "10" ]; then
      echo "FAIL: node_exporter /metrics never exposed node_ series after 10 attempts"
      docker logs node-exporter-test
      docker stop node-exporter-test && docker rm node-exporter-test
      exit 1
    fi
    sleep 2
  done

  docker stop node-exporter-test && docker rm node-exporter-test
else
  echo "node_exporter failed to start, checking logs..."
  docker logs node-exporter-test 2>&1 || true
  docker rm node-exporter-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All node_exporter tests passed!"
