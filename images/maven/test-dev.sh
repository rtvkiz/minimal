#!/bin/bash
# Smoke test for minimal-maven-dev.
# Same functional checks as prod, PLUS: bash, apk, git and a C compiler.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing maven version..."
v=$(docker run --rm "$IMAGE" -v 2>&1)
echo "$v" | grep -qE 'Apache Maven 3\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected mvn -v: $v"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT

echo "Testing an offline project lifecycle (validate a pom, no network)..."
cat > "$work/pom.xml" <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>dev.minimal</groupId>
  <artifactId>smoke</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>
</project>
POM
chmod 0644 "$work/pom.xml"
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" -o -B validate 2>&1) \
  || { echo "FAIL: mvn -o validate failed: $out"; exit 1; }
echo "$out" | grep -q 'BUILD SUCCESS' || { echo "FAIL: no BUILD SUCCESS: $out"; exit 1; }

echo "Verifying bash, apk, git and cc present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; git --version; cc --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All maven-dev tests passed!"
