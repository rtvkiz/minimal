#!/bin/bash
# Smoke test for minimal-kong-ingress-controller (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing the version subcommand reports the injected release..."
v=$(docker run --rm --network none "$IMAGE" version 2>&1 || true)
echo "$v" | grep -qE '"release":"v[0-9]+\.[0-9]+\.[0-9]+"' || { echo "FAIL: unexpected version output: $v"; exit 1; }
echo "$v" | grep -q 'NOT_SET' && { echo "FAIL: version not injected: $v"; exit 1; } || true

echo "Testing --help (flags load)..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
for f in --kong-admin-url --ingress-class --gateway-api-controller-name --kubeconfig; do
  echo "$h" | grep -q -- "$f" || { echo "FAIL: --help is missing $f"; exit 1; }
done

echo "Testing the upstream entrypoint path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = '["/manager"]' ] || { echo "FAIL: entrypoint is $ep, upstream's chart runs /manager"; exit 1; }

echo "Testing the manager fails cleanly without a cluster..."
out=$(timeout 60 docker run --rm --network none "$IMAGE" --kong-admin-url=http://127.0.0.1:8001 2>&1 || true)
echo "$out" | grep -q 'failed to create manager' || { echo "FAIL: unexpected output without a cluster:"; echo "$out" | tail -8; exit 1; }
echo "$out" | grep -qE 'no configuration has been provided|in-cluster configuration' || { echo "FAIL: did not reach the kube client:"; echo "$out" | tail -8; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All kong-ingress-controller tests passed!"
