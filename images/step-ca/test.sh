#!/bin/bash
# Smoke test for minimal-step-ca (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing step-ca version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE '0\.[0-9]+|Smallstep' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing step-ca help (subcommands load)..."
docker run --rm "$IMAGE" help 2>&1 | grep -qiE 'certificate authority|token|provisioner|onboard|version' \
  || { echo "FAIL: expected CA help text"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All step-ca tests passed!"
