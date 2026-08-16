#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing thanos version..."
docker run --rm --entrypoint /usr/bin/thanos "$IMAGE" --version 2>&1 | grep -qiE 'thanos.*version [0-9]'

echo "Testing thanos help (subcommands load)..."
docker run --rm --entrypoint /usr/bin/thanos "$IMAGE" --help 2>&1 | grep -qiE 'query|sidecar|store'

echo "Testing thanos query starts and serves /-/healthy..."
docker run -d --name thanos-test \
  -p 19090:10902 \
  "$IMAGE" query \
    --http-address=0.0.0.0:10902 \
    --grpc-address=0.0.0.0:10901
sleep 5

if docker ps | grep -q thanos-test; then
  echo "thanos container is running"
  docker logs thanos-test 2>&1 | tail -5

  echo "Checking /-/healthy at :19090..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://localhost:19090/-/healthy >/dev/null 2>&1; then
      echo "thanos /-/healthy OK (attempt $i)"
      break
    fi
    if [ "$i" = "10" ]; then
      echo "FAIL: thanos /-/healthy never returned 200 after 10 attempts"
      docker logs thanos-test
      docker stop thanos-test && docker rm thanos-test
      exit 1
    fi
    sleep 2
  done

  docker stop thanos-test && docker rm thanos-test
else
  echo "thanos failed to start, checking logs..."
  docker logs thanos-test 2>&1 || true
  docker rm thanos-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All thanos tests passed!"
