#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` can SIGPIPE.
set -eu

echo "Testing mosquitto version..."
docker run --rm --entrypoint /usr/bin/mosquitto "$IMAGE" -h 2>&1 | head -1 | grep -qi "mosquitto"

echo "Testing mosquitto_pub present..."
docker run --rm --entrypoint /usr/bin/mosquitto_pub "$IMAGE" --help 2>&1 | head -1 | grep -qi "mosquitto_pub"

echo "Testing mosquitto broker starts..."
docker run -d --name mosquitto-test \
  -p 11883:1883 \
  "$IMAGE"
sleep 4

if docker ps | grep -q mosquitto-test; then
  echo "mosquitto container is running"
  docker logs mosquitto-test 2>&1 | tail -5

  # Pub/sub round-trip via a sidecar container sharing the host network.
  # mosquitto_pub will exit non-zero if it can't reach the broker.
  echo "Publishing test message to broker on host:11883..."
  if docker run --rm --network host --entrypoint /usr/bin/mosquitto_pub "$IMAGE" \
       -h localhost -p 11883 -t minimal/test -m "ok" -q 1; then
    echo "mosquitto_pub round-trip OK"
  else
    echo "FAIL: mosquitto_pub could not reach broker"
    docker logs mosquitto-test
    docker stop mosquitto-test && docker rm mosquitto-test
    exit 1
  fi

  docker stop mosquitto-test && docker rm mosquitto-test
else
  echo "mosquitto failed to start, checking logs..."
  docker logs mosquitto-test 2>&1 || true
  docker rm mosquitto-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All mosquitto tests passed!"
