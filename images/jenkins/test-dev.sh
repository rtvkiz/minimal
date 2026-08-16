#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"
echo "Testing jenkins.war present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -f /usr/share/jenkins/jenkins.war"
echo "Testing JRE present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/lib/jvm/java-21-minimal/bin/java"
echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok
echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok
echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools
echo "Testing git (prod parity)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"
echo "Testing curl/openssl/jq/dig present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v 2>&1 | grep -qE '^DiG'"
echo "✓ All jenkins-dev smoke tests passed"
