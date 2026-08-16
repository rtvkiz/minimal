#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"
echo "Testing keycloak entrypoint present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /opt/keycloak/bin/kc.sh"
echo "Testing JDK 21 present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "/usr/lib/jvm/java-21-openjdk/bin/java -version" 2>&1 | grep -qE 'openjdk version "21'
echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok
echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok
echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools
echo "Testing curl/openssl/jq/dig present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v 2>&1 | grep -qE '^DiG'"
echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"
echo "✓ All keycloak-dev smoke tests passed"
