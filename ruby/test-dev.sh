#!/bin/bash
# Smoke test for minimal-ruby-dev.
# Validates the dev variant has shell + toolchain + bundler while preserving
# ruby-minimal runtime parity (same entrypoint, same curated gem set).
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing Ruby version (parity with prod)..."
docker run --rm "$IMAGE" -v

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

echo "Testing bundler is baked in (no runtime install needed)..."
bundler_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "bundle --version && bundler --version")
echo "$bundler_ver" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" || { echo "::error::bundler version output unexpected: $bundler_ver"; exit 1; }

echo "Testing gem install --user-install works for nonroot..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "gem install --no-document --user-install rake && ~/.gem/ruby/*/bin/rake --version" | grep -q "rake,"

echo "Testing curated json 2.19.x still active (prod parity)..."
docker run --rm "$IMAGE" -e 'require "json"; v=JSON::VERSION; raise "got #{v}" unless v.start_with?("2.19.")' \
  && echo "✓ json 2.19.x"

echo "Testing core libs (openssl, yaml, json)..."
docker run --rm "$IMAGE" -e "require 'openssl'; require 'yaml'; require 'json'; puts 'Core libs OK'" \
  | grep -q "Core libs OK"

echo "✓ All ruby-dev smoke tests passed"
