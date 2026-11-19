#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container="minimal-matomo-test-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing PHP-FPM version..."
version=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" --version 2>&1)
echo "$version" | grep -q "fpm-fcgi" || { echo "Not an FPM build: $version"; exit 1; }

echo "Testing PHP-FPM configuration..."
fpmtest=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -t 2>&1)
echo "$fpmtest" | grep -q "test is successful" || { echo "php-fpm config test failed: $fpmtest"; exit 1; }

echo "Testing Matomo-required PHP extensions..."
# Matomo's Diagnostics plugin: required (zlib json filter hash session), a
# database adapter (PDO + pdo_mysql, or mysqli), gd, and the recommended set.
mods=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -m 2>&1)
# A packaged extension that fails to load (pdo_mysql without mysqlnd) is only a
# startup warning; it would otherwise just look like an absent module.
if echo "$mods" | grep -qi "warning"; then echo "FAIL: PHP startup warning: $mods"; exit 1; fi
for ext in zlib json filter hash session PDO pdo_mysql mysqli gd mbstring libxml dom SimpleXML openssl iconv curl opcache; do
  echo "$mods" | grep -qix "$ext" || echo "$mods" | grep -qix "Zend $ext" \
    || { echo "FAIL: missing PHP extension $ext"; exit 1; }
done

echo "Testing a real FastCGI request through Matomo..."
# End-to-end and fully offline: with no config.ini.php yet, Matomo boots core,
# its DI container and Twig, and renders the first installer step. Reaching it
# proves bootstrap.php, the vendor autoloader and the template cache all work.
docker run -d --name "$container" "$IMAGE" >/dev/null
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")

ready=false
for _ in $(seq 1 30); do
  if timeout 2 bash -c "</dev/tcp/${ip}/9000" 2>/dev/null; then ready=true; break; fi
  sleep 1
done
[ "$ready" = true ] || { docker logs "$container"; echo "php-fpm never accepted connections"; exit 1; }

page=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/matomo/index.php 2>/dev/null)
echo "$page" | grep -q "X-Powered-By: PHP" || { echo "No PHP response: $page"; exit 1; }
echo "$page" | grep -q "<title>Matomo .* Installation" || { echo "Matomo installer did not render: $page"; exit 1; }
# PHP's own error markup — the page's translation strings legitimately contain
# words like "Warning: ", so a bare-text match would false-positive.
if echo "$page" | grep -qE "<b>(Deprecated|Warning|Fatal error|Notice)</b>:"; then
  echo "FAIL: installer page carries PHP errors: $page"; exit 1
fi

echo "Verifying runtime data lands outside the docroot..."
# bootstrap.php must have pointed PIWIK_USER_PATH at /var/lib/matomo: the
# request above compiled Twig templates, which Matomo writes under
# <user path>/tmp. docker cp needs no shell inside the image.
docker cp "$container:/var/lib/matomo/tmp/templates_c" - >/dev/null 2>&1 \
  || { echo "FAIL: no compiled templates under /var/lib/matomo/tmp — PIWIK_USER_PATH not relocated"; exit 1; }

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

echo "All Matomo tests passed!"
