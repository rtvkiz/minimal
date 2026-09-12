#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# kyverno has no --version flag: it registers klog-style flags via the plain
# `flag` package and defines none for version ("flag provided but not defined:
# -version"). It does log the injected version at startup from
# pkg/version/version.go before touching the cluster, so that line is the
# assertion for the pkg/version.BuildVersion ldflag. Output is colourised, so
# strip ANSI before matching.
echo "Testing kyverno logs its injected version at startup..."
# NB: no `head` here. kyverno trace-logs every one of its ~200 flags at startup,
# so the version line is first but the cluster-config error is far past line 40 —
# truncating the capture made the failure-mode assertion below look broken.
out=$(timeout 60 docker run --rm "$IMAGE" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true)

echo "$out" | grep -qE 'version=1\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected (pkg/version.BuildVersion ldflag wrong?)"; \
       echo "$out" | head -5; exit 1; }

echo "Testing kyverno flags load..."
docker run --rm "$IMAGE" -h 2>&1 | grep -qiE 'admissionReports|kubeconfig|serverIP' \
  || { echo "FAIL: -h did not list the expected flags"; exit 1; }

echo "Testing kyverno fails cleanly with no cluster config..."
case "$out" in
  *KYVERNO_NAMESPACE*|*"environment variable must be defined"*|*"in-cluster"*|\
  *KUBERNETES_SERVICE_HOST*|*"unable to"*|*"failed to"*|*"connection refused"*) ;;
  *) echo "FAIL: unexpected output with no cluster:"; echo "$out" | tail -5; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All kyverno tests passed"
