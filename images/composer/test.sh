#!/bin/bash
# Smoke test for minimal-composer (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing composer version..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^Composer version 2\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected composer --version: $v"; exit 1; }
echo "$v" | grep -qE 'PHP version 8\.5\.' || { echo "FAIL: expected PHP 8.5: $v"; exit 1; }

echo "Testing composer help lists its commands..."
h=$(docker run --rm "$IMAGE" list 2>&1)
echo "$h" | grep -qE '^\s+dump-autoload' || { echo "FAIL: unexpected composer list: $h"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
# composer writes vendor/ and the lock file as uid 65532; remove them through
# the image itself before the host-side rm, which cannot delete them.
trap 'docker run --rm -v "$work:/app" --entrypoint /bin/sh "$IMAGE" -c "rm -rf /app/vendor /app/composer.lock" >/dev/null 2>&1; rm -rf "$work"' EXIT

echo "Testing an offline install + PSR-4 autoload round trip (no network)..."
# A project with no dependencies: validate the manifest, install (writes the
# lock file and vendor/autoload.php), then load a class through the generated
# autoloader with php. Exercises phar, json, the filesystem layer and the
# autoload generator without touching Packagist.
mkdir -p "$work/src"
cat > "$work/composer.json" <<'JSON'
{
  "name": "minimal/smoke",
  "description": "smoke test",
  "license": "MIT",
  "type": "project",
  "autoload": { "psr-4": { "Smoke\\": "src/" } },
  "require": {}
}
JSON
cat > "$work/src/Hello.php" <<'PHP'
<?php
namespace Smoke;
final class Hello { public static function say(): string { return "composer-autoload-ok"; } }
PHP
chmod 0644 "$work/composer.json" "$work/src/Hello.php"; chmod 0777 "$work/src"
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" validate --strict 2>&1) \
  || { echo "FAIL: composer validate: $out"; exit 1; }
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" install --no-interaction --no-progress 2>&1) \
  || { echo "FAIL: composer install: $out"; exit 1; }
[ -s "$work/vendor/autoload.php" ] || { echo "FAIL: no vendor/autoload.php: $out"; exit 1; }
[ -s "$work/composer.lock" ] || { echo "FAIL: no composer.lock: $out"; exit 1; }
run=$(docker run --rm --network none -v "$work:/app" --entrypoint /usr/bin/php "$IMAGE" \
  -r 'require "vendor/autoload.php"; echo Smoke\Hello::say();' 2>&1)
[ "$run" = "composer-autoload-ok" ] || { echo "FAIL: autoloaded class: $run"; exit 1; }

echo "Testing the PHP extensions Composer relies on are loaded..."
mods=$(docker run --rm --entrypoint /usr/bin/php "$IMAGE" -m 2>&1)
for m in Phar openssl zip mbstring ctype curl; do
  echo "$mods" | grep -qx "$m" || { echo "FAIL: PHP extension $m not loaded"; exit 1; }
done

echo "Testing git is available for VCS repositories..."
g=$(docker run --rm --entrypoint /usr/bin/git "$IMAGE" --version 2>&1)
echo "$g" | grep -qE '^git version 2\.' || { echo "FAIL: git: $g"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying shell is busybox only (Symfony Process needs /bin/sh; no bash/apk)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo shell-ok" 2>&1 | grep -q 'shell-ok' \
  || { echo "FAIL: expected busybox /bin/sh to be present"; exit 1; }
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: bash found — restraint guard violated"; exit 1; } \
  || echo "No bash (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All composer tests passed!"
