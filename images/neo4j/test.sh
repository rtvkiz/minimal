#!/bin/bash
# Smoke test for minimal-neo4j (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing neo4j version..."
ver=$(docker run --rm --entrypoint /usr/bin/neo4j "$IMAGE" version 2>&1)
echo "$ver" | grep -qE 'neo4j [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: could not read neo4j version: $ver"; exit 1; }
echo "$ver"

echo "Testing cypher-shell is present..."
cs=$(docker run --rm --entrypoint /usr/bin/cypher-shell "$IMAGE" --version 2>&1)
echo "$cs" | grep -qi 'cypher-shell' \
  || { echo "FAIL: cypher-shell did not run: $cs"; exit 1; }

echo "Testing neo4j-admin is present..."
na=$(docker run --rm --entrypoint /usr/bin/neo4j-admin "$IMAGE" --version 2>&1)
echo "$na" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: neo4j-admin did not run: $na"; exit 1; }

# A docker-managed volume (not a host bind mount) is shared between the
# one-off admin container and the server container: uid 65532 writes into
# it, and only Docker needs to be able to clean it up afterward — a host
# bind mount would leave uid-65532-owned files the test's own (host) user
# cannot rm. Set an initial password up front (the real product flow, same
# as the official docker image's entrypoint) rather than disabling auth.
vol="minimal-neo4j-test-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT

# A fresh named volume's populate-on-first-use doesn't reliably carry over
# the image path's uid:gid (observed root-owned here), and neo4j's own lock
# file check refuses to start against a directory it doesn't own — so chown
# it explicitly as root before anything runs as nonroot.
docker run --rm -u root -v "$vol:/var/lib/neo4j/data" \
  --entrypoint /bin/sh "$IMAGE" -c 'chown -R 65532:65532 /var/lib/neo4j/data'

echo "Setting the initial password (offline)..."
docker run --rm -v "$vol:/var/lib/neo4j/data" \
  --entrypoint /usr/bin/neo4j-admin "$IMAGE" \
  dbms set-initial-password minimal-test-password 2>&1 \
  | grep -qi 'not.*Neo4j is running\|Changed password' \
  || true  # neo4j-admin's success output varies by version; verified functionally below instead

echo "Starting neo4j and waiting for the HTTP endpoint..."
cid=$(docker run -d -p 17474:7474 -p 17687:7687 \
        -v "$vol:/var/lib/neo4j/data" \
        "$IMAGE")
trap 'docker logs "$cid" 2>&1 | tail -40; docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:17474/" 2>/dev/null || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 2
done
[ "$ok" = 1 ] || { echo "FAIL: neo4j HTTP endpoint never returned 200"; exit 1; }
echo "HTTP endpoint is up"

echo "Running a real query via cypher-shell (offline)..."
out=$(docker run --rm --network "container:$cid" --entrypoint /usr/bin/cypher-shell "$IMAGE" \
        -a bolt://127.0.0.1:7687 -u neo4j -p minimal-test-password --format plain 'RETURN 1 AS x;' 2>&1)
echo "$out" | grep -q '^1$' \
  || { echo "FAIL: cypher-shell query did not return 1: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

# --- Shell policy for this image -------------------------------------------
# neo4j / neo4j-admin / cypher-shell are bash scripts (see melange.yaml), so
# bash is REQUIRED here — unlike most prod images. Only guard against
# apk-tools leaking into prod (restraint).
echo "Verifying apk-tools is ABSENT (prod restraint)..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v apk' >/dev/null 2>&1; then
  echo "FAIL: apk-tools found in prod image"; exit 1
fi
echo "no apk-tools (as expected)"

echo "All neo4j tests passed!"
