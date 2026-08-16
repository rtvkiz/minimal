#!/bin/bash
# Smoke test for minimal-kube-state-metrics-dev.
# Same functional checks as prod, PLUS: a shell IS present and the HTTP/TLS
# debugging tools are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kube-state-metrics version..."
docker run --rm --entrypoint /usr/bin/kube-state-metrics "$IMAGE" version 2>&1 \
  | grep -qE 'version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected"; exit 1; }

echo "Testing help/subcommands load..."
docker run --rm --entrypoint /usr/bin/kube-state-metrics "$IMAGE" --help 2>&1 | grep -qi 'resources' \
  || { echo "FAIL: --help did not list the expected flags"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying curl/jq/openssl/dig are present..."
for t in curl jq openssl dig; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $t" >/dev/null 2>&1 \
    || { echo "FAIL: $t missing from dev image"; exit 1; }
done

echo "All kube-state-metrics dev tests passed!"
