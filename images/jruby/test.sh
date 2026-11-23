#!/bin/bash
# Smoke test for minimal-jruby (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work" 2>/dev/null || true' EXIT

echo "Testing jruby version..."
v=$(docker run --rm --network none "$IMAGE" -v 2>&1)
echo "$v" | grep -qE '^jruby 10\.[0-9]+\.[0-9]+\.[0-9]+ \([0-9.]+\) .* OpenJDK 64-Bit Server VM 25\.' \
  || { echo "FAIL: unexpected jruby -v: $v"; exit 1; }
echo "$v" | grep -qiE 'warning|unable|illegal' && { echo "FAIL: JVM warnings on startup: $v"; exit 1; } || true

echo "Testing Ruby stdlib, OpenSSL and Java interop in one script (no network)..."
out=$(docker run --rm --network none "$IMAGE" -e '
  require "json"; require "openssl"; require "java"
  h = OpenSSL::Digest::SHA256.hexdigest("x")[0,8]
  l = java.util.ArrayList.new([1, 2, 3])
  puts JSON.generate(sum: l.to_a.sum, sha: h, ruby: RUBY_VERSION >= "3.4")' 2>&1)
[ "$out" = '{"sum":6,"sha":"2d711642","ruby":true}' ] || { echo "FAIL: script output: $out"; exit 1; }

echo "Testing the bundled tools via -S (gem, bundle, rake)..."
for t in "gem --version" "bundle --version" "rake --version"; do
  docker run --rm --network none "$IMAGE" -S $t >/dev/null 2>&1 || { echo "FAIL: jruby -S $t"; exit 1; }
done

echo "Testing gem build + install into GEM_HOME as nonroot (offline, from a local gem)..."
mkdir -p "$work/smoke/lib"
cat > "$work/smoke/smoke.gemspec" <<'RUBY'
Gem::Specification.new do |s|
  s.name = "smoke"; s.version = "0.1.0"; s.summary = "smoke"; s.authors = ["minimal"]
  s.files = ["lib/smoke.rb"]; s.license = "MIT"
end
RUBY
echo 'module Smoke; def self.hi = "smoke-gem-ok"; end' > "$work/smoke/lib/smoke.rb"
chmod -R a+rwX "$work/smoke"
out=$(docker run --rm --network none -v "$work/smoke:/work" "$IMAGE" -e '
  require "rubygems/package"; require "rubygems/installer"
  f = Gem::Package.build(Gem::Specification.load("smoke.gemspec"))
  Gem::Installer.at(f).install
  Gem.refresh
  require "smoke"; puts Smoke.hi; puts Gem::Specification.find_by_name("smoke").gem_dir' 2>&1) || true
echo "$out" | grep -qx 'smoke-gem-ok' || { echo "FAIL: gem build/install: $out"; exit 1; }
echo "$out" | grep -q '^/usr/local/bundle/gems/smoke-0.1.0$' || { echo "FAIL: gem not installed to GEM_HOME: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All jruby tests passed!"
