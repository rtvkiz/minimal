#!/bin/bash
# Smoke test for minimal-rust-dev.
# Same functional checks as prod, PLUS: bash, apk, git, pkg-config + openssl.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing cargo version..."
cv=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$cv" | grep -qE '^cargo 1\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected cargo --version: $cv"; exit 1; }

# A named volume, not a bind mount: cargo writes the project and target/ as
# uid 65532, which the host user cannot delete, and the prod image has no
# shell to clean up with. The volume is removed whole on exit.
vol="minimal-rust-smoke-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
# An empty named volume takes the image's /app ownership (65532) on first
# mount, so nonroot can write to it with no chown step.

echo "Testing an offline compile + link + run (no network)..."
out=$(docker run --rm --network none -v "$vol:/app" "$IMAGE" new --vcs none --offline hello 2>&1) \
  || { echo "FAIL: cargo new failed: $out"; exit 1; }
out=$(docker run --rm --network none -v "$vol:/app" -w /app/hello "$IMAGE" build --offline 2>&1) \
  || { echo "FAIL: cargo build failed: $out"; exit 1; }
run=$(docker run --rm --network none -v "$vol:/app" --entrypoint /app/hello/target/debug/hello "$IMAGE" 2>&1)
echo "$run" | grep -q 'Hello, world!' || { echo "FAIL: built binary did not run: $run"; exit 1; }

echo "Verifying bash, apk, git and pkg-config/openssl present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; git --version; pkg-config --modversion openssl' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All rust-dev tests passed!"
