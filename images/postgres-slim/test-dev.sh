#!/bin/bash
# Smoke test for minimal-postgres-slim-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing postgres version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -qE "^postgres \(PostgreSQL\) (18|19)"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing psql client present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "psql --version" | grep -qE "^psql"

echo "Testing pg_dump present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "pg_dump --version" | grep -qE "^pg_dump"

echo "Testing pg_basebackup present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "pg_basebackup --version" | grep -qE "^pg_basebackup"

echo "Testing pg_isready present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "pg_isready --version" | grep -qE "^pg_isready"

echo "Testing gosu present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gosu --version" 2>&1 | grep -qE "^[0-9]+\.[0-9]+"

echo "Testing curl/socat/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && socat -V >/dev/null 2>&1 && jq --version >/dev/null"

echo "Testing initdb works..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "initdb --version" | grep -qE "^initdb"

echo "✓ All postgres-slim-dev smoke tests passed"
