#!/bin/bash
# Smoke test for minimal-harbor-portal (prod).
set -euo pipefail

echo "Testing Harbor portal starts and serves the UI..."
docker run -d --name harbor-portal-test -p 0:8080 "$IMAGE"
trap 'docker rm -f harbor-portal-test >/dev/null 2>&1 || true' EXIT

PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' harbor-portal-test)

ok=0
for _ in $(seq 1 20); do
  if [ -z "$(docker ps -q --filter name=harbor-portal-test)" ]; then break; fi
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/" || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
  sleep 1
done

if [ "$ok" != 1 ]; then
  echo "FAIL: portal did not serve the UI"
  docker logs harbor-portal-test 2>&1 || true
  exit 1
fi

body=$(curl -s "http://localhost:${PORT}/")
echo "$body" | grep -qi "<title>Harbor</title>" || { echo "FAIL: index.html missing Harbor title: $body"; exit 1; }

echo "Verifying SPA fallback (Angular router paths return index.html, not 404)..."
spa_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/some/angular/route")
[ "$spa_code" = "200" ] || { echo "FAIL: expected 200 SPA fallback, got $spa_code"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && { echo "FAIL: shell found in image!"; exit 1; } \
  || echo "No shell confirmed"

echo "✓ All harbor-portal tests passed"
