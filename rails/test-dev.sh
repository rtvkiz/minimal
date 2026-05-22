#!/bin/bash
# Smoke test for minimal-rails-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing Ruby version (parity with prod)..."
docker run --rm "$IMAGE" -v | grep -qE "^ruby 4"

echo "Testing Rails available (parity with prod)..."
docker run --rm "$IMAGE" -e "require 'rails'; puts Rails.version" | grep -qE "^[0-9]+\.[0-9]+"

echo "Testing Bundler (already in prod)..."
bundle_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "bundle --version")
echo "$bundle_ver" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" || { echo "::error::bundle version unexpected: $bundle_ver"; exit 1; }

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

echo "Testing Node.js + npm (asset pipeline)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "node --version && npm --version" >/dev/null

echo "Testing yarn..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "yarn --version" | grep -qE "^[0-9]+\.[0-9]+"

echo "Testing gem install --user-install works..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "gem install --no-document --user-install rake && ~/.gem/ruby/*/bin/rake --version" | grep -q "rake,"

echo "✓ All rails-dev smoke tests passed"
