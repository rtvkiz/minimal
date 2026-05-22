#!/bin/bash
# Smoke test for minimal-rabbitmq-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing rabbitmq-server present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /opt/rabbitmq/sbin/rabbitmq-server"

echo "Testing rabbitmqctl present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /opt/rabbitmq/sbin/rabbitmqctl"

echo "Testing erlang runtime..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "erl -version" 2>&1 | grep -qE "Erlang"

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

echo "✓ All rabbitmq-dev smoke tests passed"
