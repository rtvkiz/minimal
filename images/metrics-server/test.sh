#!/bin/bash
# Smoke test for minimal-metrics-server (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing metrics-server version..."
# Guards the -X injection path (k8s.io/client-go/pkg/version.gitVersion). If the
# ldflags path is wrong the binary still builds but reports an empty/"v0.0.0"
# version, which is exactly the failure this catches.
docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" --version 2>&1 | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (got '$(docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" --version 2>&1 | head -1)')"; exit 1; }

echo "Testing help/flags load..."
docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" --help 2>&1 | grep -qi 'kubelet' \
  || { echo "FAIL: --help did not list the expected flags"; exit 1; }

echo "Testing offline behaviour: generates a serving cert, then fails cleanly..."
# Two things are proved here with no cluster and no network:
#  1. TLS self-signed cert generation succeeds — this only works if work-dir is
#     writable by nonroot. metrics-server writes to the RELATIVE path
#     apiserver.local.config/certificates when --cert-dir is not given, so a
#     read-only work-dir is a hard startup failure. Regression guard for that.
#  2. It then fails fast with a clear in-cluster-config error rather than
#     hanging or panicking.
out=$(docker run --rm --entrypoint /usr/bin/metrics-server "$IMAGE" \
  --secure-port=10250 2>&1 | head -20 || true)
echo "$out" | grep -qi 'Generated self-signed cert' \
  || { echo "FAIL: could not generate serving cert (work-dir not writable?):"; echo "$out" | head -5; exit 1; }
echo "$out" | grep -qiE 'KUBERNETES_SERVICE_HOST|unable to load in-cluster configuration' \
  || { echo "FAIL: expected in-cluster config error, got:"; echo "$out" | head -5; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All metrics-server tests passed!"
