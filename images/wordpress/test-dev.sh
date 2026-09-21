#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

# Expected version comes from melange.yaml, never a literal. A hardcoded
# version turns every auto-bump PR red on its own smoke test while the build
# itself is fine — which is exactly what happened to the meilisearch 1.54.0
# bump (#744): both melange arches built, then prod and dev failed the version
# grep. Reading the recipe asserts the real invariant (the image ships what the
# recipe pins) and survives bumps untouched.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi

echo "Testing WordPress version parity with production..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "grep -q \"wp_version = .$EXPECTED.\" /usr/share/wordpress/wp-includes/version.php"

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
