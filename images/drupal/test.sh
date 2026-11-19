#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container="minimal-drupal-test-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing PHP-FPM version..."
version=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" --version 2>&1)
echo "$version" | grep -q "fpm-fcgi" || { echo "Not an FPM build: $version"; exit 1; }

echo "Testing PHP-FPM configuration..."
fpmtest=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -t 2>&1)
echo "$fpmtest" | grep -q "test is successful" || { echo "php-fpm config test failed: $fpmtest"; exit 1; }

echo "Testing Drupal-required PHP extensions..."
# core/composer.json's ext-* requirements, plus one PDO driver per database.
mods=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -m 2>&1)
# A packaged extension that fails to load (pdo_mysql without mysqlnd) is only a
# startup warning; it would otherwise just look like an absent module.
if echo "$mods" | grep -qi "warning"; then echo "FAIL: PHP startup warning: $mods"; exit 1; fi
for ext in PDO pdo_mysql pdo_pgsql pdo_sqlite dom gd SimpleXML xml date filter hash json pcre session SPL tokenizer zlib mbstring opcache; do
  echo "$mods" | grep -qix "$ext" || echo "$mods" | grep -qix "Zend $ext" \
    || { echo "FAIL: missing PHP extension $ext"; exit 1; }
done

echo "Testing a real FastCGI request through Drupal..."
# End-to-end and fully offline: with no database configured, Drupal's front
# controller boots the kernel, finds no installed site and redirects to the
# installer — and the installer renders its first page. Reaching both proves
# PHP parsed settings.php, the vendor autoloader resolved and core booted; a
# missing extension or a broken settings file fails here instead.
docker run -d --name "$container" "$IMAGE" >/dev/null
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")

ready=false
for _ in $(seq 1 30); do
  if timeout 2 bash -c "</dev/tcp/${ip}/9000" 2>/dev/null; then ready=true; break; fi
  sleep 1
done
[ "$ready" = true ] || { docker logs "$container"; echo "php-fpm never accepted connections"; exit 1; }

front=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/drupal/index.php 2>/dev/null)
echo "$front" | grep -qi "^Location:.*core/install.php" \
  || { echo "Front controller did not redirect to the installer: $front"; exit 1; }

installer=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/drupal/core/install.php 2>/dev/null)
echo "$installer" | grep -q "X-Powered-By: PHP" || { echo "No PHP response: $installer"; exit 1; }
echo "$installer" | grep -qi "Choose language" \
  || { echo "Drupal installer did not render: $installer"; exit 1; }
# Drupal renders PHP notices into the page rather than the FPM log, and one
# notice before the session starts is enough to break the next installer step.
if echo "$installer" | grep -qE "(Deprecated function|Warning|Notice|Error)</em>|Deprecated function:|Warning: "; then
  echo "FAIL: installer page carries PHP errors: $installer"; exit 1
fi

echo "Verifying version-leaking files were stripped..."
leak=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/drupal/core/CHANGELOG.txt 2>/dev/null || true)
echo "$leak" | grep -qi "Primary Script Unknown\|404\|File not found\|Access denied" \
  || { echo "FAIL: core/CHANGELOG.txt is still present and servable"; exit 1; }

logs=$(docker logs "$container" 2>&1)
if echo "$logs" | grep -qE "PHP (Fatal|Warning|Deprecated)"; then
  echo "FAIL: PHP reported errors while serving: $logs"
  exit 1
fi

echo "Verifying production image has no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-found' >/dev/null 2>&1; then
  echo "FAIL: production image contains /bin/sh"
  exit 1
fi

echo "All Drupal tests passed!"
