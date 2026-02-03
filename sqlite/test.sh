#!/bin/bash
set -euo pipefail

echo "Testing SQLite version..."
docker run --rm "$IMAGE" --version

echo "Testing in-memory query..."
docker run --rm "$IMAGE" :memory: "SELECT 1;"

echo "Testing file-based DB..."
docker run --rm "$IMAGE" /tmp/test.db "CREATE TABLE t(x); INSERT INTO t VALUES(1); SELECT * FROM t;"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
