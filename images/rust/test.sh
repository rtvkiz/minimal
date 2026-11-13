#!/bin/bash
# Smoke test for minimal-rust (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing cargo and rustc versions..."
cv=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$cv" | grep -qE '^cargo 1\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected cargo --version: $cv"; exit 1; }
rv=$(docker run --rm --entrypoint /usr/bin/rustc "$IMAGE" --version 2>&1)
echo "$rv" | grep -qE '^rustc 1\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected rustc --version: $rv"; exit 1; }

echo "Testing cargo help..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -q 'build' || { echo "FAIL: unexpected cargo --help: $h"; exit 1; }

# A named volume, not a bind mount: cargo writes the project and target/ as
# uid 65532, which the host user cannot delete, and the prod image has no
# shell to clean up with. The volume is removed whole on exit.
vol="minimal-rust-smoke-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
# An empty named volume takes the image's /app ownership (65532) on first
# mount, so nonroot can write to it with no chown step.

echo "Testing an offline compile + link + run (no network)..."
# Exercises rustc -> cc -> ld: the linker path is the part a toolchain image
# most often gets wrong (missing crt1.o / libc.so linker script).
out=$(docker run --rm --network none -v "$vol:/app" "$IMAGE" new --vcs none --offline hello 2>&1) \
  || { echo "FAIL: cargo new failed: $out"; exit 1; }
out=$(docker run --rm --network none -v "$vol:/app" -w /app/hello "$IMAGE" build --offline --release 2>&1) \
  || { echo "FAIL: cargo build failed: $out"; exit 1; }
run=$(docker run --rm --network none -v "$vol:/app" --entrypoint /app/hello/target/release/hello "$IMAGE" 2>&1)
echo "$run" | grep -q 'Hello, world!' || { echo "FAIL: built binary did not run: $run"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"

echo "All rust tests passed!"
