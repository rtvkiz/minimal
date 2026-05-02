#!/bin/bash
set -euo pipefail

echo "Testing Loki version..."
docker run --rm "$IMAGE" -version

echo "Testing Loki starts..."
docker run -d --name loki-test "$IMAGE"

READY_BODY=$(mktemp)
READY_ERR=$(mktemp)
READY_CODE=""

for i in $(seq 1 30); do
  if ! docker ps --format '{{.Names}}' | grep -qx loki-test; then
    echo "Loki container exited before becoming ready"
    docker logs loki-test 2>&1 || true
    docker rm loki-test 2>/dev/null || true
    rm -f "$READY_BODY" "$READY_ERR"
    exit 1
  fi

  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' loki-test)
  READY_CODE=$(curl -sS -o "$READY_BODY" -w '%{http_code}' "http://${IP}:3100/ready" 2>"$READY_ERR" || true)

  if [ "$READY_CODE" = "200" ]; then
    head -c 200 "$READY_BODY"
    echo ""
    echo "Loki is running and ready (attempt ${i})"
    docker stop loki-test && docker rm loki-test
    rm -f "$READY_BODY" "$READY_ERR"
    echo "✓ Loki tests passed"
    exit 0
  fi

  sleep 2
done

echo "Loki did not become ready after 60s"
echo "Last /ready HTTP status: ${READY_CODE:-unknown}"
if [ -s "$READY_BODY" ]; then
  echo "Last /ready response:"
  head -c 500 "$READY_BODY"
  echo ""
fi
if [ -s "$READY_ERR" ]; then
  echo "Last curl error:"
  cat "$READY_ERR"
fi
echo "Container logs:"
docker logs loki-test 2>&1 || true
docker stop loki-test 2>/dev/null || true
docker rm loki-test 2>/dev/null || true
rm -f "$READY_BODY" "$READY_ERR"
exit 1

echo "✓ Loki tests passed"
