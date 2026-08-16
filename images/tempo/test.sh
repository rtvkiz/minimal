#!/bin/bash
# NB: no -o pipefail — `curl LARGE | grep -q` is SIGPIPE-prone.
set -eu

echo "Testing tempo version..."
docker run --rm --entrypoint /usr/bin/tempo "$IMAGE" -version

echo "Testing tempo starts in single-binary mode..."
docker run -d --name tempo-test \
  -p 13200:3200 \
  "$IMAGE"
sleep 6

if docker ps | grep -q tempo-test; then
  echo "tempo container is running"
  docker logs tempo-test 2>&1 | tail -5

  # /ready returns 200 once all modules are running. We retry with -f
  # because tempo returns 503 during startup until live-store/distributor
  # are healthy (typically <10s).
  echo "Checking /ready at :13200..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://localhost:13200/ready >/dev/null 2>&1; then
      echo "tempo /ready OK (attempt $i)"
      break
    fi
    if [ "$i" = "10" ]; then
      echo "FAIL: tempo /ready never returned 200 after 10 attempts"
      docker logs tempo-test
      docker stop tempo-test && docker rm tempo-test
      exit 1
    fi
    sleep 2
  done

  echo "Checking /metrics at :13200..."
  if ! curl -sf http://localhost:13200/metrics >/dev/null 2>&1; then
    echo "FAIL: tempo /metrics failed"
    docker stop tempo-test && docker rm tempo-test
    exit 1
  fi
  echo "tempo /metrics OK"

  docker stop tempo-test && docker rm tempo-test
else
  echo "tempo failed to start, checking logs..."
  docker logs tempo-test 2>&1 || true
  docker rm tempo-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All tempo tests passed!"
