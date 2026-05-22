#!/bin/bash
# Smoke test for minimal-opensearch-dev.
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing OpenSearch JAR present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /usr/share/opensearch/lib/opensearch-*.jar | head -1" >/dev/null

echo "Testing JDK 21 present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "/usr/lib/jvm/java-21-openjdk/bin/java -version" 2>&1 | grep -qE "openjdk version \"21"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl + jq present (HTTP API debugging)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && jq --version >/dev/null"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "✓ All opensearch-dev smoke tests passed"
