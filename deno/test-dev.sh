#!/bin/bash
# Smoke test for minimal-deno-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing Deno version (parity with prod)..."
docker run --rm "$IMAGE" --version | head -1 | grep -qE "^deno "

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

echo "Testing deno run (TypeScript out of the box)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
echo "console.log(\"deno ts ok\")" > /tmp/hello.ts && deno run --allow-all /tmp/hello.ts
' | grep -q "deno ts ok"

echo "Testing deno's bundled tools (fmt, lint)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "deno fmt --help | head -1 && deno lint --help | head -1" >/dev/null

echo "✓ All deno-dev smoke tests passed"
