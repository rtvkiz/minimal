#!/bin/bash
# Smoke test for minimal-maven (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing maven version..."
v=$(docker run --rm "$IMAGE" -v 2>&1)
echo "$v" | grep -qE 'Apache Maven 3\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected mvn -v: $v"; exit 1; }
echo "$v" | grep -qE 'Java version: [0-9]+' || { echo "FAIL: mvn found no JDK: $v"; exit 1; }

echo "Testing maven help..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -q -- '--offline' || { echo "FAIL: unexpected mvn --help: $h"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT

echo "Testing an offline project lifecycle (validate a pom, no network)..."
# `validate` has no default plugin bindings for pom packaging, so this exercises
# POM parsing, model building and the reactor without fetching from Central.
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

echo "Testing the JDK compiles and runs Java (javac is present, not just a JRE)..."
cat > "$work/Hello.java" <<'JAVA'
public class Hello { public static void main(String[] a) { System.out.println("hello-from-javac"); } }
JAVA
chmod 0644 "$work/Hello.java"
run=$(docker run --rm --network none -v "$work:/app" --entrypoint /usr/lib/jvm/default-jvm/bin/java "$IMAGE" Hello.java 2>&1)
echo "$run" | grep -q 'hello-from-javac' || { echo "FAIL: java source launch failed: $run"; exit 1; }
jc=$(docker run --rm --entrypoint /usr/lib/jvm/default-jvm/bin/javac "$IMAGE" -version 2>&1)
echo "$jc" | grep -qE '^javac [0-9]+' || { echo "FAIL: javac missing: $jc"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying shell is busybox only (mvn's launcher-script exception, no bash/apk)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo shell-ok" 2>&1 | grep -q 'shell-ok' \
  || { echo "FAIL: expected busybox /bin/sh to be present"; exit 1; }
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: bash found — restraint guard violated"; exit 1; } \
  || echo "No bash (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All maven tests passed!"
