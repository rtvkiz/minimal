#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

echo "Testing WordPress version parity with production..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'grep -q "wp_version = .7.1.1." /usr/share/wordpress/wp-includes/version.php'

echo "Testing PHP CLI can parse WordPress core..."
# A real syntax check of the bootstrap the FPM request exercises.
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'php -l /usr/share/wordpress/wp-settings.php && php -l /usr/share/wordpress/wp-config.php'

echo "Testing /bin/sh and /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'test "$(echo sh-ok)" = sh-ok'
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'test "$(echo bash-ok)" = bash-ok'

echo "Testing apk-tools and standard debugging tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'apk --version >/dev/null && curl --version >/dev/null && wget --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v >/dev/null 2>&1 && git --version >/dev/null'

echo "All WordPress dev tests passed!"
