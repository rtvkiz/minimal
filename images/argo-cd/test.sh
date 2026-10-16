#!/bin/bash
# Smoke test for minimal-argo-cd (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing argocd version (client-only, no server needed)..."
v=$(docker run --rm "$IMAGE" version --client 2>&1)
echo "$v" | grep -qE 'argocd: v[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected version output: $v"; exit 1; }

echo "Testing argocd help (subcommands load)..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -qiE 'server|application-controller|repo-server' \
  || { echo "FAIL: expected component subcommands in help: $h"; exit 1; }

echo "Testing argocd app (CLI offline, exercises cobra/flag parsing)..."
docker run --rm "$IMAGE" app --help 2>&1 | grep -qi 'application' \
  || { echo "FAIL: 'argocd app --help' did not look right"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } || echo "No shell (as expected)"

echo "All argo-cd tests passed!"
