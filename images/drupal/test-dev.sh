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

echo "Testing Drupal version parity with production..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "grep -q \"const VERSION = '$EXPECTED'\" /usr/share/drupal/core/lib/Drupal.php"

echo "Testing PHP CLI loads Drupal's autoloader and settings..."
got=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'php -l /usr/share/drupal/sites/default/settings.php >/dev/null && php -r "require \"/usr/share/drupal/autoload.php\"; echo \Drupal::VERSION, PHP_EOL;"')
[ "$got" = "$EXPECTED" ] || { echo "FAIL: autoloaded Drupal::VERSION is '$got', expected $EXPECTED"; exit 1; }

echo "Testing a full install from the environment, then serving the site..."
# smoke-install.php runs Drupal's installer non-interactively with SQLite and
# no database form, so it must read settings.php's env-driven $databases and
# finish with that file read-only. The same container's PHP-FPM then serves
# the installed front page, which must carry the site name the install set.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container="minimal-drupal-dev-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$container" \
  -e DRUPAL_DB_DRIVER=sqlite -e DRUPAL_DB_NAME=/var/lib/drupal/drupal.sqlite \
  -e DRUPAL_HASH_SALT=smoketest-hash-salt-0123456789abcdef \
  "$IMAGE" >/dev/null
installed=$(docker exec -i "$container" php < "$here/smoke-install.php" 2>&1)
echo "$installed" | grep -qx "INSTALLED $EXPECTED" || { echo "FAIL: install did not complete: $installed"; exit 1; }

ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
front=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/drupal/index.php 2>/dev/null)
echo "$front" | grep -q "<title>.*smoketest" || { echo "FAIL: installed site did not render: $front"; exit 1; }

echo "Testing /bin/sh and /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'test "$(echo sh-ok)" = sh-ok'
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'test "$(echo bash-ok)" = bash-ok'

echo "Testing apk-tools and standard debugging tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'apk --version >/dev/null && curl --version >/dev/null && wget --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v >/dev/null 2>&1 && git --version >/dev/null'

echo "All Drupal dev tests passed!"
