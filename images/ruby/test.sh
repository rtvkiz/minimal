#!/bin/bash
set -euo pipefail

echo "Testing Ruby version..."
docker run --rm "$IMAGE" -v

echo "Testing RubyGems..."
docker run --rm "$IMAGE" -e "require 'rubygems'; puts Gem::VERSION"

echo "Verifying curated gem set (bundler, net-imap, rexml stripped; json bumped)..."
docker run --rm "$IMAGE" -e '
  raise "bundler should be stripped" if begin require "bundler"; true; rescue LoadError; false; end
  raise "net/imap should be stripped" if begin require "net/imap"; true; rescue LoadError; false; end
  raise "rexml should be stripped" if begin require "rexml/document"; true; rescue LoadError; false; end
  require "json"
  raise "json must be >=2.19, got #{JSON::VERSION}" unless JSON::VERSION.start_with?("2.19.")
  puts "Curated gem set verified (json #{JSON::VERSION})"
'

echo "Testing core libraries (openssl, yaml, json)..."
docker run --rm "$IMAGE" -e "require 'openssl'; require 'yaml'; require 'json'; puts 'Core libs OK'"

echo "Testing default workdir..."
docker run --rm "$IMAGE" -e "puts Dir.pwd" | grep -qx /work

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
