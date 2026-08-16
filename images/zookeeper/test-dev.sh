#!/bin/bash
# Smoke test for minimal-zookeeper-dev.
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing Java (parity with prod) ..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qiE 'openjdk|21'

echo "Testing ZooKeeper JARs present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /opt/zookeeper/lib/zookeeper-*.jar | wc -l | grep -qvE '^0$'"

echo "Testing /bin/sh + /bin/bash ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "✓ All zookeeper-dev smoke tests passed"
