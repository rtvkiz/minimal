#!/bin/bash
set -euo pipefail

echo "Testing Traefik version..."
docker run --rm --entrypoint /usr/bin/traefik "$IMAGE" version

echo "Testing Traefik healthcheck (--ping)..."
docker run -d --name traefik-test "$IMAGE" \
  --ping --ping.entryPoint=ping \
  --entryPoints.ping.address=:8082
sleep 2

if docker ps | grep -q traefik-test; then
  echo "Traefik is running"
  docker logs traefik-test
  docker stop traefik-test && docker rm traefik-test
else
  echo "Traefik failed to start, checking logs..."
  docker logs traefik-test 2>&1 || true
  docker rm traefik-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"
