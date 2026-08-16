#!/bin/bash
# Smoke test for minimal-php-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing PHP version (parity with prod)..."
docker run --rm "$IMAGE" -v | grep -qE "^PHP 8\."

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing C toolchain (gcc, make, pkgconf)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gcc --version && make --version && pkgconf --version" >/dev/null

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing PHP extensions present (openssl, mbstring, curl, libxml)..."
docker run --rm "$IMAGE" -r "echo extension_loaded('openssl') ? 'openssl-OK' : 'openssl-MISSING'; echo PHP_EOL;
echo extension_loaded('mbstring') ? 'mbstring-OK' : 'mbstring-MISSING'; echo PHP_EOL;
echo extension_loaded('curl') ? 'curl-OK' : 'curl-MISSING'; echo PHP_EOL;
echo extension_loaded('libxml') ? 'libxml-OK' : 'libxml-MISSING'; echo PHP_EOL;" \
  | grep -c "OK" | grep -q "^4$"

echo "Testing simple PHP script execution..."
docker run --rm "$IMAGE" -r "echo 'hello php', PHP_EOL;" | grep -q "hello php"

echo "✓ All php-dev smoke tests passed"
