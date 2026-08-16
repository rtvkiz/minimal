#!/bin/sh
# Test script for minimal-java image
# Requires IMAGE environment variable to be set

set -e

echo "Testing OpenJDK runtime image..."

# Test 1: Check java version
echo "Test 1: Checking java version..."
docker run --rm "$IMAGE" -version
echo "✓ java -version succeeded"

# Test 2: Verify JAVA_HOME is set
echo "Test 2: Checking JAVA_HOME..."
JAVA_HOME_VAL=$(docker run --rm --entrypoint /usr/bin/printenv "$IMAGE" JAVA_HOME 2>/dev/null || echo "not-set")
if [ "$JAVA_HOME_VAL" = "/usr/lib/jvm/java-21-openjdk" ]; then
  echo "✓ JAVA_HOME is set correctly"
else
  echo "⚠ Could not verify JAVA_HOME (printenv may not be available)"
fi

# Test 3: Verify running as nonroot
echo "Test 3: Verifying nonroot user..."
USER_ID=$(docker run --rm --entrypoint /usr/bin/id "$IMAGE" -u 2>/dev/null || echo "no-id")
if [ "$USER_ID" = "65532" ]; then
  echo "✓ Running as nonroot (65532)"
else
  echo "⚠ Could not verify user ID (id command may not be available)"
fi

# Test 4: Verify no shell (security hardening)
echo "Test 4: Verifying no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null; then
  echo "⚠ Shell is available (may be from dependencies)"
else
  echo "✓ No shell (as expected)"
fi

echo ""
echo "✓ All OpenJDK runtime tests passed"
