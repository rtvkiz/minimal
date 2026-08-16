#!/bin/bash
# Smoke test for minimal-kube-state-metrics (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kube-state-metrics version..."
# NOTE: `version` is a SUBCOMMAND here, not a --version flag (that errors with
# "unknown flag"). The version string comes from
# github.com/prometheus/common/version.Version — upstream's shared package, not
# this project's own module path — so a wrong -X target yields an empty version
# while still building cleanly. That is what this grep guards.
docker run --rm --entrypoint /usr/bin/kube-state-metrics "$IMAGE" version 2>&1 \
  | grep -qE 'version [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: version not injected"; exit 1; }

echo "Testing help/subcommands load..."
docker run --rm --entrypoint /usr/bin/kube-state-metrics "$IMAGE" --help 2>&1 | grep -qi 'resources' \
  || { echo "FAIL: --help did not list the expected flags"; exit 1; }

echo "Testing offline behaviour: full init path runs, then fails clearly..."
# kube-state-metrics contacts the API server BEFORE it binds any listener, so
# there is no way to scrape /metrics without a cluster. What can be proved
# offline is that the whole startup path executes: flags parse, the resource
# registry is built, allow/deny lists are applied, and the client attempts a
# real connection - then it exits with a specific, actionable error rather than
# hanging or panicking.
out=$(docker run --rm --entrypoint /usr/bin/kube-state-metrics "$IMAGE" \
  --apiserver=http://127.0.0.1:1 2>&1 | head -20 || true)
for expect in "Starting kube-state-metrics" "Used default resources" "Metric allow-denylisting"; do
  echo "$out" | grep -q "$expect" \
    || { echo "FAIL: init path did not reach '$expect'"; echo "$out" | head -8; exit 1; }
done
echo "$out" | grep -qiE 'error while trying to communicate with apiserver|connection refused' \
  || { echo "FAIL: expected a clear apiserver connection error, got:"; echo "$out" | head -8; exit 1; }
echo "init path complete; exited with a clear apiserver error (as expected offline)"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All kube-state-metrics tests passed!"
