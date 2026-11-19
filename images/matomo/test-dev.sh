#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

# Expected version comes from melange.yaml, never a literal, so auto-bump PRs
# don't fail their own smoke test.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi

echo "Testing Matomo console reports the packaged version..."
got=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'cd /usr/share/matomo && php console --version 2>/dev/null')
echo "$got" | grep -qx "Matomo $EXPECTED" || { echo "FAIL: console reported '$got', expected Matomo $EXPECTED"; exit 1; }

echo "Testing Matomo's own system check..."
# diagnostics:run is the installer's System Check from the CLI: required PHP
# extensions and functions, a usable database adapter, writable tmp/ and
# config/ under PIWIK_USER_PATH. It must report no errors. The two expected
# warnings — no TLS (terminated by the web server in front) and a read-only
# matomo.js (the image's code is immutable) — are not failures.
diag=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'cd /usr/share/matomo && php console diagnostics:run 2>&1' || true)
if echo "$diag" | grep -qE "errors detected|: ERROR|- ERROR"; then
  echo "FAIL: Matomo system check reported errors:"; echo "$diag"; exit 1
fi
echo "$diag" | grep -qE "warnings detected|No problems" || { echo "FAIL: system check did not run: $diag"; exit 1; }

echo "Testing /bin/sh and /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'test "$(echo sh-ok)" = sh-ok'
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'test "$(echo bash-ok)" = bash-ok'

echo "Testing apk-tools and standard debugging tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'apk --version >/dev/null && curl --version >/dev/null && wget --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v >/dev/null 2>&1 && git --version >/dev/null'

echo "All Matomo dev tests passed!"
