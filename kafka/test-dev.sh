#!/bin/bash
# Smoke test for minimal-kafka-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing JRE present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /usr/lib/jvm/*/bin/java | head -1" >/dev/null

echo "Testing kafka entrypoint exists..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/kafka-entrypoint.sh"

echo "Testing kafka libs shipped..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /opt/kafka/libs/kafka-server-*.jar | head -1" >/dev/null

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

echo "✓ All kafka-dev smoke tests passed"
