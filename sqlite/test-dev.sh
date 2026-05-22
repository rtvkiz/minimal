#!/bin/bash
# Smoke test for minimal-sqlite-dev.
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing sqlite3 version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -qE "^[0-9]+\.[0-9]+"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl + jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing sqlite3 actually works (CREATE + INSERT + SELECT)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "sqlite3 /tmp/test.db 'CREATE TABLE t(x INTEGER); INSERT INTO t VALUES (42); SELECT x FROM t;'" | grep -q "^42$"

echo "✓ All sqlite-dev smoke tests passed"
