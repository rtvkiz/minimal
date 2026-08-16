#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing blackbox_exporter version..."
docker run --rm --entrypoint /usr/bin/blackbox_exporter "$IMAGE" --version 2>&1 | grep -qiE 'blackbox_exporter.*version [0-9]'

echo "Testing blackbox_exporter help..."
docker run --rm --entrypoint /usr/bin/blackbox_exporter "$IMAGE" --help 2>&1 | grep -qiE 'config.file|web.listen-address'

echo "Testing blackbox_exporter starts (default config) and serves /metrics..."
docker run -d --name blackbox-exporter-test \
  -p 19115:9115 \
  "$IMAGE" --config.file=/etc/blackbox_exporter/config.yml --web.listen-address=0.0.0.0:9115
sleep 3

if docker ps | grep -q blackbox-exporter-test; then
  echo "blackbox_exporter container is running"
  docker logs blackbox-exporter-test 2>&1 | tail -5

  echo "Checking /metrics at :19115 exposes blackbox_ series..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://localhost:19115/metrics 2>/dev/null | grep -q '^blackbox_'; then
      echo "blackbox_exporter /metrics OK (attempt $i)"
      break
    fi
    if [ "$i" = "10" ]; then
      echo "FAIL: blackbox_exporter /metrics never exposed blackbox_ series after 10 attempts"
      docker logs blackbox-exporter-test
      docker stop blackbox-exporter-test && docker rm blackbox-exporter-test
      exit 1
    fi
    sleep 2
  done

  docker stop blackbox-exporter-test && docker rm blackbox-exporter-test
else
  echo "blackbox_exporter failed to start, checking logs..."
  docker logs blackbox-exporter-test 2>&1 || true
  docker rm blackbox-exporter-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All blackbox_exporter tests passed!"
