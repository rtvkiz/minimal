#!/bin/bash
set -euo pipefail

echo "Testing Fluent Bit version..."
docker run --rm "$IMAGE" --version

echo "Testing Fluent Bit starts..."
docker run -d --name fluentbit-test "$IMAGE"

HEALTH_BODY=$(mktemp)
HEALTH_ERR=$(mktemp)
HEALTH_CODE=""

for i in $(seq 1 30); do
  if ! docker ps --format '{{.Names}}' | grep -qx fluentbit-test; then
    echo "Fluent Bit container exited before becoming healthy"
    docker logs fluentbit-test 2>&1 || true
    docker rm fluentbit-test 2>/dev/null || true
    rm -f "$HEALTH_BODY" "$HEALTH_ERR"
    exit 1
  fi

  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' fluentbit-test)
  HEALTH_CODE=$(curl -sS -o "$HEALTH_BODY" -w '%{http_code}' "http://${IP}:2020/api/v1/health" 2>"$HEALTH_ERR" || true)

  if [ "$HEALTH_CODE" = "200" ]; then
    head -c 200 "$HEALTH_BODY"
    echo ""
    echo "Fluent Bit is running and healthy (attempt ${i})"
    docker stop fluentbit-test && docker rm fluentbit-test
    rm -f "$HEALTH_BODY" "$HEALTH_ERR"
    echo "✓ Fluent Bit tests passed"
    exit 0
  fi

  sleep 2
done

echo "Fluent Bit did not become healthy after 60s"
echo "Last /api/v1/health HTTP status: ${HEALTH_CODE:-unknown}"
if [ -s "$HEALTH_BODY" ]; then
  echo "Last health response:"
  head -c 500 "$HEALTH_BODY"
  echo ""
fi
if [ -s "$HEALTH_ERR" ]; then
  echo "Last curl error:"
  cat "$HEALTH_ERR"
fi
echo "Container logs:"
docker logs fluentbit-test 2>&1 || true
docker stop fluentbit-test 2>/dev/null || true
docker rm fluentbit-test 2>/dev/null || true
rm -f "$HEALTH_BODY" "$HEALTH_ERR"
exit 1
