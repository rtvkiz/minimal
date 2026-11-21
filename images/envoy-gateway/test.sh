#!/bin/bash
# Smoke test for minimal-envoy-gateway (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing envoy-gateway version..."
v=$(docker run --rm --network none "$IMAGE" version 2>&1 || true)
echo "$v" | grep -qE '^ENVOY_GATEWAY_VERSION: v[0-9]+\.[0-9]+\.[0-9]+$' || { echo "FAIL: unexpected version output: $v"; exit 1; }
echo "$v" | grep -qE '^GATEWAYAPI_VERSION: v[0-9]+' || { echo "FAIL: Gateway API version missing: $v"; exit 1; }

echo "Testing subcommands load..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
for c in server certgen envoy; do
  echo "$h" | grep -qE "^  $c " || { echo "FAIL: subcommand $c missing: $h"; exit 1; }
done

echo "Testing certgen --local generates the control-plane PKI (no cluster, no network)..."
work=$(mktemp -d); chmod 0777 "$work"; trap 'rm -rf "$work" 2>/dev/null || true' EXIT
out=$(docker run --rm --network none -v "$work:/certs" "$IMAGE" certgen --local --config-home /certs 2>&1 || true)
echo "$out" | grep -q 'generated certificates' || { echo "FAIL: certgen: $out"; exit 1; }
for f in envoy-gateway/ca.crt envoy-gateway/tls.crt envoy/tls.crt envoy-rate-limit/tls.crt; do
  [ -s "$work/certs/$f" ] || { echo "FAIL: certgen did not write certs/$f"; ls -R "$work"; exit 1; }
done

echo "Testing server boots its runners, then exits without a cluster..."
# With no config file it loads the default (Kubernetes provider) config, starts
# its runners, and exits non-zero when the provider cannot reach an API server.
# It prints no error line for that, so assert on the boot log + exit code.
rc=0
out=$(timeout 60 docker run --rm --network none "$IMAGE" server 2>&1) || rc=$?
echo "$out" | grep -q 'running hook.*"provider": "Kubernetes"' || { echo "FAIL: default config not loaded:"; echo "$out" | tail -10; exit 1; }
echo "$out" | grep -q 'Start runners' || { echo "FAIL: runners never started:"; echo "$out" | tail -10; exit 1; }
[ "$rc" = "1" ] || { echo "FAIL: expected exit 1 without a cluster, got $rc (124 = hung)"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All envoy-gateway tests passed!"
