#!/bin/bash
# Smoke test for minimal-metrics-server-dev.
# Same functional checks as prod, PLUS: a shell IS present and the TLS/HTTP
# debugging tools are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing metrics-server version..."
docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" --version 2>&1 | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected"; exit 1; }

echo "Testing help/flags load..."
docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" --help 2>&1 | grep -qi 'kubelet' \
  || { echo "FAIL: --help did not list the expected flags"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying curl/jq/openssl/dig are present..."
for t in curl jq openssl dig; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $t" >/dev/null 2>&1 \
    || { echo "FAIL: $t missing from dev image"; exit 1; }
done

echo "All metrics-server dev tests passed!"
