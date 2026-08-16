#!/bin/bash
# Smoke test for minimal-mariadb-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing mariadbd version (parity with prod)..."
docker run --rm --entrypoint /usr/sbin/mariadbd "$IMAGE" --version | grep -qE "mariadbd"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing mariadb client (mariadb / mysql CLI)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "mariadb --version" | grep -qE "mariadb"

echo "Testing mysql compatibility CLI..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "mysql --version" | grep -qE "(mysql|mariadb)"

echo "Testing mariadb-install-db present (db init)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/mariadb-install-db"

echo "Testing curl/socat/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && socat -V >/dev/null 2>&1 && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All mariadb-dev smoke tests passed"
