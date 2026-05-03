#!/bin/bash
set -euo pipefail

echo "Testing Keycloak starts in dev mode..."
docker run -d --name keycloak-test \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  "$IMAGE" start-dev

READY_BODY=$(mktemp)
READY_ERR=$(mktemp)
READY_CODE=""

for i in $(seq 1 30); do
  if ! docker ps --format '{{.Names}}' | grep -qx keycloak-test; then
    echo "Keycloak container exited before becoming ready"
    docker logs keycloak-test 2>&1 || true
    docker rm keycloak-test 2>/dev/null || true
    rm -f "$READY_BODY" "$READY_ERR"
    exit 1
  fi

  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' keycloak-test)
  READY_CODE=$(curl -sS -o "$READY_BODY" -w '%{http_code}' "http://${IP}:8080/health/ready" 2>"$READY_ERR" || true)

  if [ "$READY_CODE" = "200" ]; then
    head -c 200 "$READY_BODY"
    echo ""
    echo "Keycloak is running and healthy (attempt ${i})"
    docker stop keycloak-test && docker rm keycloak-test
    rm -f "$READY_BODY" "$READY_ERR"
    echo "✓ Keycloak tests passed"
    exit 0
  fi

  sleep 2
done

echo "Keycloak did not become ready after 60s"
echo "Last /health/ready HTTP status: ${READY_CODE:-unknown}"
if [ -s "$READY_BODY" ]; then
  echo "Last readiness response:"
  head -c 500 "$READY_BODY"
  echo ""
fi
if [ -s "$READY_ERR" ]; then
  echo "Last curl error:"
  cat "$READY_ERR"
fi
echo "Container logs:"
docker logs keycloak-test 2>&1 || true
docker stop keycloak-test 2>/dev/null || true
docker rm keycloak-test 2>/dev/null || true
rm -f "$READY_BODY" "$READY_ERR"
exit 1
