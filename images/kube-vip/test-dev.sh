#!/bin/bash
# Smoke test for minimal-kube-vip-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing kube-vip version (parity with prod)..."
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'Version: +v?1\.[0-9]+\.[0-9]+'

echo "Testing kube-vip manifest generation (parity with prod)..."
docker run --rm "$IMAGE" manifest pod \
  --interface eth0 --address 192.168.0.40 --controlplane --arp 2>&1 | grep -q 'kind: Pod'

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "Testing ip(8) present (network debugging)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ip -V" | grep -qi 'iproute2'

echo "All kube-vip-dev tests passed!"
