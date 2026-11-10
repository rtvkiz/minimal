#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container="minimal-phpmyadmin-test-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing PHP-FPM version..."
version=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" --version 2>&1)
echo "$version" | grep -q "fpm-fcgi" || { echo "Not an FPM build: $version"; exit 1; }
echo "$version" | grep -q "^PHP 8\.3\." || { echo "Expected PHP 8.3 (phpMyAdmin 5.2 supports <8.4): $version"; exit 1; }

echo "Testing PHP-FPM configuration..."
docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -t 2>&1 | grep -q "test is successful" \
  || { echo "php-fpm config test failed"; exit 1; }

echo "Testing phpMyAdmin-required PHP extensions..."
mods=$(docker run --rm --entrypoint /usr/bin/php-fpm "$IMAGE" -m 2>/dev/null)
for ext in mysqli mysqlnd mbstring ctype iconv sodium openssl xml dom SimpleXML xmlwriter zip gd session; do
  echo "$mods" | grep -qix "$ext" || { echo "FAIL: missing PHP extension $ext"; exit 1; }
done

echo "Testing a real FastCGI request through phpMyAdmin..."
# Fully offline: no database is needed to render the login page. Reaching it
# proves PHP parsed config.inc.php (including the generated cookie secret),
# loaded vendor/ and rendered the twig templates from the writable TempDir.
docker run -d --name "$container" "$IMAGE" >/dev/null
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
ready=false
for _ in $(seq 1 30); do
  if timeout 2 bash -c "</dev/tcp/${ip}/9000" 2>/dev/null; then ready=true; break; fi
  sleep 1
done
[ "$ready" = true ] || { docker logs "$container"; echo "php-fpm never accepted connections"; exit 1; }

body=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/phpmyadmin/index.php 2>/dev/null)
echo "$body" | grep -q "X-Powered-By: PHP\|Content-Type: text/html" || { echo "No PHP response: $(echo "$body" | head -20)"; exit 1; }
echo "$body" | grep -q 'name="pma_username"' || { echo "FAIL: login form not rendered: $(echo "$body" | head -40)"; exit 1; }
if echo "$body" | grep -qiE "Fatal error|Deprecated:|Warning:|Notice:"; then
  echo "FAIL: PHP errors in the response"; echo "$body" | grep -iE "Fatal error|Deprecated:|Warning:|Notice:" | head; exit 1
fi
echo "✓ login page rendered with no PHP errors"

echo "Verifying the setup wizard is not servable..."
leak=$(python3 "$here/fcgi-probe.py" "$ip" 9000 /usr/share/phpmyadmin/setup/index.php 2>/dev/null || true)
echo "$leak" | grep -qi "Primary Script Unknown\|404\|File not found" \
  || { echo "FAIL: setup/ is present and servable"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying production image has no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-found' >/dev/null 2>&1; then
  echo "FAIL: production image contains /bin/sh"
  exit 1
fi

echo "All phpMyAdmin tests passed!"
