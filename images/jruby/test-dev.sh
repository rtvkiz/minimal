#!/bin/bash
# Smoke test for minimal-jruby-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

echo "Testing JRuby's own launchers work through the shell (dev only)..."
out=$(docker run --rm --network none --entrypoint /bin/sh "$IMAGE" -c 'jruby -e "puts 1+1" && gem --version >/dev/null && bundle --version >/dev/null && irb --version >/dev/null && echo launchers-ok' 2>&1)
echo "$out" | grep -q '^2$' || { echo "FAIL: jruby launcher: $out"; exit 1; }
echo "$out" | grep -q 'launchers-ok' || { echo "FAIL: gem/bundle/irb launchers: $out"; exit 1; }

echo "Testing the prod-style entrypoint still works..."
out=$(docker run --rm --network none "$IMAGE" -e 'puts RUBY_ENGINE' 2>&1)
[ "$out" = "jruby" ] || { echo "FAIL: entrypoint: $out"; exit 1; }

echo "Testing bash, apk, git and jq present..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'apk --version && git --version && jq --version'

echo "All jruby-dev tests passed!"
