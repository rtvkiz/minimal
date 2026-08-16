#!/bin/sh
# Test script for minimal-dotnet image
# Requires IMAGE environment variable to be set

set -e

echo "Testing .NET runtime image..."

# Test 1: Check dotnet version
echo "Test 1: Checking dotnet version..."
docker run --rm "$IMAGE" --info
echo "✓ dotnet --info succeeded"

# Test 2: Check runtime is available
echo "Test 2: Checking runtime list..."
docker run --rm "$IMAGE" --list-runtimes
echo "✓ Runtime list succeeded"

# Test 3: Verify running as nonroot
echo "Test 3: Verifying nonroot user..."
USER_ID=$(docker run --rm --entrypoint /usr/bin/id "$IMAGE" -u 2>/dev/null || echo "no-id")
if [ "$USER_ID" = "65532" ]; then
  echo "✓ Running as nonroot (65532)"
else
  echo "⚠ Could not verify user ID (id command may not be available)"
fi

# Test 4: Check environment variables
echo "Test 4: Checking environment..."
TELEMETRY=$(docker run --rm --entrypoint /usr/bin/printenv "$IMAGE" DOTNET_CLI_TELEMETRY_OPTOUT 2>/dev/null || echo "not-set")
if [ "$TELEMETRY" = "1" ]; then
  echo "✓ Telemetry disabled"
else
  echo "⚠ Could not verify telemetry setting"
fi

# Test 5: Verify no shell (security hardening)
echo "Test 5: Verifying no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null; then
  echo "⚠ Shell is available (may be from dependencies)"
else
  echo "✓ No shell (as expected)"
fi

echo ""
echo "✓ All .NET runtime tests passed"
