#!/bin/bash
set -euo pipefail

echo "Testing Mimir version..."
docker run --rm --entrypoint /usr/bin/mimir "$IMAGE" -version

echo "Testing mimirtool version..."
docker run --rm --entrypoint /usr/bin/mimirtool "$IMAGE" version

echo "Testing Mimir config validation..."
# -modules: print the module dependency graph and exit. Also validates the
# config file end-to-end without binding ports.
docker run --rm --entrypoint /usr/bin/mimir "$IMAGE" \
  -config.file=/etc/mimir/config.yaml -modules >/dev/null

echo "Testing Mimir starts, serves /ready, and exits cleanly..."
docker run -d --name mimir-test \
  --entrypoint /usr/bin/mimir \
  "$IMAGE" \
  -config.file=/etc/mimir/config.yaml
# Mimir's monolithic mode takes ~15s to bring all components up.
for i in 1 2 3 4 5 6 7 8 9 10; do
  if docker exec mimir-test wget -q -O - http://localhost:8080/ready 2>/dev/null | grep -q ready; then
    echo "Mimir is ready"
    break
  fi
  sleep 3
done

if ! docker ps | grep -q mimir-test; then
  echo "Mimir failed to stay running, logs:"
  docker logs mimir-test 2>&1 | tail -30
  docker rm mimir-test 2>/dev/null || true
  exit 1
fi
docker stop mimir-test >/dev/null && docker rm mimir-test >/dev/null

echo "✓ Mimir tests passed"
