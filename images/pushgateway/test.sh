#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing pushgateway version..."
docker run --rm --entrypoint /usr/bin/pushgateway "$IMAGE" --version 2>&1 | grep -qiE 'pushgateway.*version [0-9]'

echo "Testing pushgateway help..."
docker run --rm --entrypoint /usr/bin/pushgateway "$IMAGE" --help 2>&1 | grep -qiE 'web.listen-address|persistence.file'

echo "Testing pushgateway starts and serves /-/healthy + /metrics..."
docker run -d --name pushgateway-test \
  -p 19091:9091 \
  "$IMAGE" --web.listen-address=0.0.0.0:9091
sleep 3

if docker ps | grep -q pushgateway-test; then
  echo "pushgateway container is running"
  docker logs pushgateway-test 2>&1 | tail -5

  echo "Checking /-/healthy at :19091..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://localhost:19091/-/healthy >/dev/null 2>&1; then
      echo "pushgateway /-/healthy OK (attempt $i)"
      break
    fi
    if [ "$i" = "10" ]; then
      echo "FAIL: pushgateway /-/healthy never returned 200 after 10 attempts"
      docker logs pushgateway-test
      docker stop pushgateway-test && docker rm pushgateway-test
      exit 1
    fi
    sleep 2
  done

  echo "Checking a pushed metric round-trips through /metrics..."
  # Pushgateway requires Prometheus text exposition format with a trailing newline.
  printf 'smoke_test_metric 42\n' | curl -sf --data-binary @- http://localhost:19091/metrics/job/smoke >/dev/null
  if curl -sf http://localhost:19091/metrics 2>/dev/null | grep -q 'smoke_test_metric'; then
    echo "pushgateway push round-trip OK"
  else
    echo "FAIL: pushed metric not visible on /metrics"
    docker logs pushgateway-test
    docker stop pushgateway-test && docker rm pushgateway-test
    exit 1
  fi

  docker stop pushgateway-test && docker rm pushgateway-test
else
  echo "pushgateway failed to start, checking logs..."
  docker logs pushgateway-test 2>&1 || true
  docker rm pushgateway-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All pushgateway tests passed!"
