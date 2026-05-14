#!/bin/bash
set -euo pipefail

echo "Testing Ruby version..."
docker run --rm "$IMAGE" -v

echo "Testing RubyGems..."
docker run --rm "$IMAGE" -e "require 'rubygems'; puts Gem::VERSION"

echo "Testing Bundler..."
docker run --rm "$IMAGE" -e "require 'bundler'; puts Bundler::VERSION"

echo "Testing core libraries (openssl, yaml, json)..."
docker run --rm "$IMAGE" -e "require 'openssl'; require 'yaml'; require 'json'; puts 'Core libs OK'"

echo "Testing default workdir..."
docker run --rm "$IMAGE" -e "puts Dir.pwd" | grep -qx /work

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
