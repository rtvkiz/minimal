#!/bin/bash
# Smoke test for minimal-neo4j-dev.
# Same functional checks as prod, PLUS: apk-tools/curl/jq are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing neo4j version..."
ver=$(docker run --rm --entrypoint /usr/bin/neo4j "$IMAGE" version 2>&1)
echo "$ver" | grep -qE 'neo4j [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: could not read neo4j version: $ver"; exit 1; }

vol="minimal-neo4j-dev-test-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT

docker run --rm -u root -v "$vol:/usr/share/neo4j/data" \
  --entrypoint /bin/sh "$IMAGE" -c 'chown -R 65532:65532 /usr/share/neo4j/data'

echo "Setting the initial password (offline)..."
docker run --rm -v "$vol:/usr/share/neo4j/data" \
  --entrypoint /usr/bin/neo4j-admin "$IMAGE" \
  dbms set-initial-password minimal-test-password 2>&1 || true

echo "Starting neo4j and waiting for the HTTP endpoint..."
cid=$(docker run -d -p 17475:7474 -p 17688:7687 \
        -v "$vol:/usr/share/neo4j/data" \
        "$IMAGE")
trap 'docker logs "$cid" 2>&1 | tail -40; docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:17475/" 2>/dev/null || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 2
done
[ "$ok" = 1 ] || { echo "FAIL: neo4j HTTP endpoint never returned 200"; exit 1; }

echo "Discovery endpoint round-trip using the image's own curl+jq..."
disc=$(docker run --rm --network "container:$cid" --entrypoint /bin/sh "$IMAGE" -c \
         'curl -sf http://127.0.0.1:7474/ | jq -c .neo4j_version' 2>/dev/null || true)
[ -n "$disc" ] \
  && echo "discovery -> $disc (fetched via in-image curl+jq)" \
  || { echo "FAIL: in-image curl+jq round-trip returned nothing"; exit 1; }

echo "Verifying apk-tools IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v apk' >/dev/null 2>&1 \
  || { echo "FAIL: apk-tools missing from dev image"; exit 1; }

echo "All neo4j dev tests passed!"
