#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

# Expected version comes from melange.yaml, never a literal, so auto-bump PRs
# do not fail their own smoke test.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
[ -n "$EXPECTED" ] || { echo "FAIL: could not read version from melange.yaml"; exit 1; }

echo "Testing phpMyAdmin version parity with production..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "grep -q \"VERSION = '$EXPECTED'\" /usr/share/phpmyadmin/libraries/classes/Version.php"

echo "Testing PHP CLI can parse the config and entry point..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'php -l /usr/share/phpmyadmin/config.inc.php && php -l /usr/share/phpmyadmin/index.php'

echo "Testing /bin/sh and /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'test "$(echo sh-ok)" = sh-ok'
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'test "$(echo bash-ok)" = bash-ok'

echo "Testing apk-tools and debugging tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "✓ All phpmyadmin-dev smoke tests passed"
