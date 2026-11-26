#!/bin/bash
# Smoke test for minimal-rethinkdb-dev: same tool as prod, plus the dev minimum.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing the tool still runs with the prod entrypoint..."
docker run --rm --network none "$IMAGE" --version >/dev/null || { echo "FAIL: --version via prod entrypoint"; exit 1; }

echo "Verifying bash, apk and wget present (dev only)..."
tools=$(docker run --rm --network none --entrypoint /bin/sh "$IMAGE" -c \
  'bash --version | head -1; apk --version; wget --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All rethinkdb-dev tests passed!"
