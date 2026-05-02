#!/bin/bash
set -euo pipefail

echo "Testing Keycloak starts in dev mode..."
docker run -d --name keycloak-test \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  "$IMAGE" start-dev
sleep 10

if docker ps | grep -q keycloak-test; then
  IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' keycloak-test)
  curl -sf "http://${IP}:8080/health/ready" | head -c 200
  echo ""
  echo "Keycloak is running and healthy"
  docker stop keycloak-test && docker rm keycloak-test
else
  echo "Keycloak failed to start, checking logs..."
  docker logs keycloak-test 2>&1 || true
  docker rm keycloak-test 2>/dev/null || true
  exit 1
fi

echo "✓ Keycloak tests passed"
