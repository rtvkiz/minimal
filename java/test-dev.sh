#!/bin/bash
# Smoke test for minimal-java-dev.
# Validates full JDK + shell + git on top of java prod (which ships JRE only).
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing Java version (parity with prod)..."
docker run --rm "$IMAGE" -version 2>&1 | grep -qE "openjdk version \"2[6-9]"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing javac (full JDK, not just JRE)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "javac -version" 2>&1 | grep -qE "javac 2[6-9]"

echo "Testing jar tool present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "jar --version" | grep -qE "^jar 2[6-9]"

echo "Testing jdeps present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "jdeps --version" | grep -qE "^2[6-9]"

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing compile + run a tiny program..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
cd /tmp && cat > Hello.java <<EOF
public class Hello { public static void main(String[] args) { System.out.println("javac+java OK"); } }
EOF
javac Hello.java && java -cp /tmp Hello
' | grep -q "javac+java OK"

echo "✓ All java-dev smoke tests passed"
