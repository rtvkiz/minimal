#!/bin/bash
# Smoke test for minimal-gatekeeper (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing --help (flags load)..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
for f in -operation -port -validating-webhook-configuration-name -constraint-violations-limit; do
  echo "$h" | grep -q -- "$f" || { echo "FAIL: --help is missing $f"; exit 1; }
done

echo "Testing the upstream entrypoint path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = '["/manager"]' ] || { echo "FAIL: entrypoint is $ep, upstream's chart runs /manager"; exit 1; }

echo "Testing the manager fails cleanly without a cluster..."
# Gets past flag parsing and logger setup, then must stop at the
# controller-runtime client - the step a client-go bump would break. Exit, not hang.
out=$(timeout 30 docker run --rm --network none "$IMAGE" --operation=audit 2>&1 || true)
case "$out" in
  *"unable to load in-cluster config"*|*"no configuration has been provided"*) ;;
  *) echo "FAIL: unexpected output without a cluster:"; echo "$out" | tail -20; exit 1 ;;
esac

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All gatekeeper tests passed!"
