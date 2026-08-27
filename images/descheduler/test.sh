#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing descheduler version..."
# `version` is a subcommand, not a flag — descheduler is a cobra command and
# rejects --version outright.
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'v?0\.[0-9]+'

echo "Testing descheduler flags load (cobra command tree intact)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'policy-config-file|descheduling-interval|dry-run'

echo "Testing descheduler fails cleanly without a cluster..."
# No kubeconfig and no in-cluster service account: it must report that clearly
# and exit, not hang or panic. Exercises client construction and the config
# path — the parts a dependency bump would break.
out=$(docker run --rm "$IMAGE" --policy-config-file=/nonexistent.yaml 2>&1 || true)
case "$out" in
  *"unable to load in-cluster configuration"*|*KUBERNETES_SERVICE_HOST*|*"no such file"*|*"failed to"*) ;;
  *) echo "FAIL: unexpected output without a cluster: $out"; exit 1 ;;
esac
echo "✓ descheduler reported a clean startup error"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All descheduler tests passed!"
