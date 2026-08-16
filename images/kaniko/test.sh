#!/bin/bash
# Smoke test for minimal-kaniko (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kaniko executor version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'v?1\.[0-9]+' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing kaniko help (flags load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE -- '--dockerfile|--context|--destination' \
  || { echo "FAIL: expected --dockerfile/--context in help"; exit 1; }

echo "Offline functional build (FROM scratch, --no-push → tarball)..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
printf 'FROM scratch\nCOPY hello.txt /hello.txt\n' > "$work/Dockerfile"
echo "hardened" > "$work/hello.txt"
docker run --rm -v "$work:/workspace" "$IMAGE" \
  --context dir:///workspace \
  --dockerfile /workspace/Dockerfile \
  --no-push --force \
  --tar-path /workspace/out.tar \
  --destination minimal-kaniko-selftest:latest >/dev/null 2>&1 || {
    echo "FAIL: kaniko build errored"; exit 1; }
[ -s "$work/out.tar" ] \
  && echo "kaniko built an image tarball offline ($(stat -c%s "$work/out.tar") bytes)" \
  || { echo "FAIL: no image tarball produced"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All kaniko tests passed!"
