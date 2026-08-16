#!/bin/bash
# Smoke test for minimal-skopeo (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing skopeo version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE 'skopeo version 1\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing skopeo help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'copy|inspect|list-tags' \
  || { echo "FAIL: expected copy/inspect in help"; exit 1; }

echo "Verifying default signature policy is present (skopeo needs it)..."
# Run an op that reads the policy then fails on the (missing) source. If
# /etc/containers/policy.json were absent, skopeo would error about policy.json
# BEFORE reaching the source — so a policy.json mention means it's missing.
out=$(docker run --rm "$IMAGE" copy dir:/tmp/nope dir:/tmp/nope2 2>&1 || true)
if printf '%s' "$out" | grep -qi 'policy.json'; then
  echo "FAIL: /etc/containers/policy.json missing (skopeo can't operate)"; echo "$out"; exit 1
fi
echo "signature policy present"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All skopeo tests passed!"
