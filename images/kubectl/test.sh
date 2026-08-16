#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone (grep closes
# the pipe early, docker exits 141, pipefail blows the script). Capture to
# a variable then grep.
set -eu

echo "Testing kubectl version --client..."
VERSION_OUT=$(docker run --rm --entrypoint /usr/bin/kubectl "$IMAGE" version --client -o yaml)
echo "$VERSION_OUT" | head -8
if ! echo "$VERSION_OUT" | grep -qE 'gitVersion: v1\.[0-9]+\.[0-9]+'; then
  echo "FAIL: expected gitVersion v1.x.y in kubectl version output"
  exit 1
fi

echo "Testing kubectl create --dry-run (offline manifest generation)..."
# --dry-run=client never touches a cluster, so this is a pure CLI smoke test.
# --network none ensures we'd fail loudly if kubectl tried to reach a cluster.
MANIFEST=$(docker run --rm --network none --entrypoint /usr/bin/kubectl "$IMAGE" \
  create namespace smoke-test --dry-run=client -o yaml)
echo "$MANIFEST" | head -6
echo "$MANIFEST" | grep -qE 'kind:\s*Namespace'
echo "$MANIFEST" | grep -qE 'name:\s*smoke-test'
echo "kubectl create --dry-run OK"

echo "Testing kubectl create configmap --dry-run (additional client-side path)..."
# Different resource + flag surface than the namespace test — exercises the
# configmap generator and --from-literal parsing, also fully offline.
CM=$(docker run --rm --network none --entrypoint /usr/bin/kubectl "$IMAGE" \
  create configmap smoke-cm --from-literal=key=value --dry-run=client -o yaml)
echo "$CM" | head -6
echo "$CM" | grep -qE 'kind:\s*ConfigMap'
echo "$CM" | grep -qE 'key:\s*value'
echo "kubectl create configmap OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All kubectl tests passed!"
