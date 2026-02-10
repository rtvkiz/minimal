#!/bin/bash
set -euo pipefail

echo "Testing Ruby version..."
docker run --rm "$IMAGE" -v

echo "Testing Rails version..."
docker run --rm "$IMAGE" -e "require 'rails'; puts Rails.version"

echo "Testing Bundler version..."
docker run --rm "$IMAGE" -e "require 'bundler'; puts Bundler::VERSION"

echo "Testing core libraries (openssl, yaml, json)..."
docker run --rm "$IMAGE" -e "require 'openssl'; require 'yaml'; require 'json'; puts 'Core libs OK'"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
