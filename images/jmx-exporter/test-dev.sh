#!/bin/bash
# Smoke test for minimal-jmx-exporter-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing both jars and the JRE present (parity with prod)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -s /opt/jmx_exporter/jmx_prometheus_standalone.jar && test -s /opt/jmx_exporter/jmx_prometheus_javaagent.jar && java -version >/dev/null 2>&1"

echo "Testing /bin/sh (busybox)..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok"); [ "$out" = sh-ok ]

echo "Testing /bin/bash..."
out=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok"); [ "$out" = bash-ok ]

echo "Testing apk-tools present..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version"); echo "$out" | grep -q apk-tools

echo "Testing curl/openssl/jq/dig present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v 2>&1 | grep -qE '^DiG'"

echo "✓ All jmx-exporter-dev smoke tests passed"
