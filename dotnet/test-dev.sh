#!/bin/bash
# Smoke test for minimal-dotnet-dev.
# Validates full SDK + shell + git on top of dotnet prod (runtime only).
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing .NET runtime version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -qE "^1[0-9]\."

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing full SDK present (dotnet build, dotnet new)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "dotnet --list-sdks" | grep -qE "^1[0-9]\."

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing dotnet new + build (end-to-end SDK exercise)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
cd /tmp && dotnet new console -n hello -o hello --no-restore >/dev/null &&
cd hello && dotnet build --nologo --verbosity quiet 2>&1 | tail -3 &&
dotnet bin/Debug/net*/hello.dll
' | grep -q "Hello, World!"

echo "✓ All dotnet-dev smoke tests passed"
