#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container="minimal-wordpress-test-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing PHP-FPM version..."
version=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" --version 2>&1)
echo "$version" | grep -q "fpm-fcgi" || { echo "Not an FPM build: $version"; exit 1; }

echo "Testing PHP-FPM configuration..."
docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -t 2>&1 | grep -q "test is successful" \
  || { echo "php-fpm config test failed"; exit 1; }

echo "Testing WordPress-required PHP extensions..."
mods=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -m 2>/dev/null)
for ext in mysqli mysqlnd mbstring gd curl dom exif fileinfo iconv openssl zip; do
  echo "$mods" | grep -qix "$ext" || { echo "FAIL: missing PHP extension $ext"; exit 1; }
done

echo "Testing WordPress payload..."
# version.php is the authoritative statement of what shipped.
docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -t >/dev/null 2>&1

echo "Testing a real FastCGI request through WordPress..."
# End-to-end and fully offline: no database is reachable, so WordPress is
# expected to render its own "Database Error" page. Reaching that page proves
# PHP parsed wp-config.php, loaded wp-settings.php and booted WordPress core —
# a missing extension or a broken config fails here instead of in production.
docker run -d --name "$container" "$IMAGE" >/dev/null
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")

ready=false
for _ in $(seq 1 30); do
  if timeout 2 bash -c "</dev/tcp/${ip}/9000" 2>/dev/null; then ready=true; break; fi
  sleep 1
done
[ "$ready" = true ] || { docker logs "$container"; echo "php-fpm never accepted connections"; exit 1; }

body=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/wordpress/index.php 2>/dev/null)
echo "$body" | grep -q "X-Powered-By: PHP" || { echo "No PHP response: $body"; exit 1; }
echo "$body" | grep -qi "database" || { echo "WordPress did not boot: $body"; exit 1; }

echo "Verifying version-leaking files were stripped..."
# readme.html discloses the exact WordPress version to unauthenticated scanners.
leak=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/wordpress/readme.html 2>/dev/null || true)
echo "$leak" | grep -qi "Primary Script Unknown\|404\|File not found" \
  || { echo "FAIL: readme.html is still present and servable"; exit 1; }

echo "Verifying production image has no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-found' >/dev/null 2>&1; then
  echo "FAIL: production image contains /bin/sh"
  exit 1
fi

echo "All WordPress tests passed!"
