#!/bin/bash
# Smoke test for minimal-helm-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing helm version (parity with prod)..."
VERSION_OUT=$(docker run --rm --entrypoint /usr/bin/helm "$IMAGE" version --short)
echo "$VERSION_OUT"
# Same rule as test.sh: assert the recipe's version rather than a hardcoded
# major, so this does not have to be edited on every major bump — and so a
# broken -X ldflags path (which stamps an EMPTY version) still fails here.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi
if ! echo "$VERSION_OUT" | grep -qE "^v${EXPECTED//./\\.}([+.-]|$)"; then
  echo "FAIL: expected v${EXPECTED} in helm version output, got: ${VERSION_OUT}"
  exit 1
fi

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/jq/git present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && jq --version >/dev/null && git --version >/dev/null"

echo "Testing bind-tools (dig)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "dig -v" 2>&1 | grep -qE "^DiG"

echo "All minimal-helm-dev smoke tests passed"
