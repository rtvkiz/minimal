#!/bin/bash
# Smoke test for minimal-patroni-dev.
# Same functional checks as prod, PLUS: bash IS present and the cluster-debugging
# tools (psql, curl, jq) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing patroni version..."
docker run --rm --entrypoint /usr/bin/patroni "$IMAGE" --version 2>&1 | grep -qiE '^patroni 4\.' \
  || { echo "FAIL: patroni version string not found"; exit 1; }

echo "Testing the managed PostgreSQL server is present..."
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version 2>&1 | grep -qiE 'PostgreSQL\) 18\.' \
  || { echo "FAIL: postgres 18 not found in image"; exit 1; }

echo "Testing initdb can bootstrap a cluster as nonroot (offline)..."
docker run --rm --tmpfs /pgtest:uid=65532,gid=65532,mode=0700 \
  --entrypoint /usr/bin/initdb "$IMAGE" -D /pgtest -U postgres --auth=trust 2>&1 \
  | grep -qi 'Success' \
  || { echo "FAIL: initdb could not bootstrap a data dir"; exit 1; }

echo "Testing sample config generation..."
docker run --rm --entrypoint /usr/bin/patroni "$IMAGE" --generate-sample-config 2>/dev/null \
  | grep -qE '^scope:' \
  || { echo "FAIL: --generate-sample-config produced no usable config"; exit 1; }

echo "Verifying bash IS present (dev)..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'echo bash-ok' 2>/dev/null | grep -q bash-ok \
  || { echo "FAIL: no bash in dev image"; exit 1; }

echo "Verifying psql/curl/jq are present..."
for t in psql curl jq; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $t" >/dev/null 2>&1 \
    || { echo "FAIL: $t missing from dev image"; exit 1; }
done

echo "All patroni dev tests passed!"
