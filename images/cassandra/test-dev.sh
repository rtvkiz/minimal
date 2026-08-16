#!/bin/bash
# Smoke test for minimal-cassandra-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing JRE present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /usr/lib/jvm/*/bin/java | head -1" >/dev/null

echo "Testing cassandra entrypoint exists..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/cassandra-entrypoint.sh"

echo "Testing cassandra libs shipped..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /opt/cassandra/lib/apache-cassandra-*.jar | head -1" >/dev/null

echo "Testing nodetool shipped..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /opt/cassandra/bin/nodetool"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/socat/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && socat -V >/dev/null 2>&1 && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All cassandra-dev smoke tests passed"
