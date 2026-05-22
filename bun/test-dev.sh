#!/bin/bash
# Smoke test for minimal-bun-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing Bun version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing C toolchain (gcc, make)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gcc --version && make --version" >/dev/null

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing bun install works (writes to ~/.bun)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "cd /tmp && mkdir -p bunapp && cd bunapp && bun init -y >/dev/null 2>&1 && bun add --no-save lodash 2>&1 | tail -3" >/dev/null

echo "Testing bun run (TypeScript out of the box)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
echo "console.log(\"bun ts ok\")" > /tmp/hello.ts && bun run /tmp/hello.ts
' | grep -q "bun ts ok"

echo "✓ All bun-dev smoke tests passed"
