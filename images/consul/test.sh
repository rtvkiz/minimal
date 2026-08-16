#!/bin/bash
# NB: no -o pipefail — `curl LARGE | grep -q` is SIGPIPE-prone (grep closes
# the pipe early, curl exits 141, pipefail blows the script). We capture curl
# output to a variable then grep, which avoids the pipe entirely.
set -eu

echo "Testing consul version..."
docker run --rm --entrypoint /usr/bin/consul "$IMAGE" version

echo "Testing consul agent starts..."
docker run -d --name consul-test \
  -p 18500:8500 \
  "$IMAGE"
sleep 8

if docker ps | grep -q consul-test; then
  echo "consul container is running"
  docker logs consul-test 2>&1 | tail -5

  echo "Checking /v1/status/leader at :18500..."
  LEADER=$(curl -sf --retry 8 --retry-delay 2 http://localhost:18500/v1/status/leader || true)
  if echo "$LEADER" | grep -qE '"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+"'; then
    echo "consul has a leader ($LEADER) — cluster healthy"
  else
    echo "FAIL: consul /v1/status/leader returned: $LEADER"
    docker logs consul-test
    docker stop consul-test && docker rm consul-test
    exit 1
  fi

  echo "Checking UI at :18500/ui/..."
  UI=$(curl -sf --retry 3 --retry-delay 1 http://localhost:18500/ui/ || true)
  if echo "$UI" | grep -qi "consul"; then
    echo "consul UI OK"
  else
    echo "FAIL: consul UI check failed"
    docker logs consul-test
    docker stop consul-test && docker rm consul-test
    exit 1
  fi

  docker stop consul-test && docker rm consul-test
else
  echo "consul failed to start, checking logs..."
  docker logs consul-test 2>&1 || true
  docker rm consul-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All consul tests passed!"
