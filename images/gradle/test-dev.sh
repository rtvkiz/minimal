#!/bin/bash
# Smoke test for minimal-gradle-dev.
# Same functional checks as prod, PLUS: bash, apk, git and a C compiler.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing gradle version..."
v=$(docker run --rm "$IMAGE" --version --no-daemon 2>&1)
echo "$v" | grep -qE '^Gradle [0-9]+\.[0-9]+' || { echo "FAIL: unexpected gradle --version: $v"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
# Gradle writes build/ and .gradle/ as uid 65532, which the host user cannot
# delete; clear them from inside a root container first. Cleanup must never
# decide the exit status, so both steps are non-fatal.
trap 'docker run --rm --user 0 -v "$work:/w" --entrypoint /bin/sh "$IMAGE" -c "rm -rf /w/* /w/.[!.]*" >/dev/null 2>&1 || true; rm -rf "$work" 2>/dev/null || true' EXIT

echo "Testing an offline Java build (compile + jar, no network)..."
mkdir -p "$work/src/main/java/smoke"
cat > "$work/settings.gradle" <<'G'
rootProject.name = 'smoke'
G
cat > "$work/build.gradle" <<'G'
plugins { id 'java' }
G
cat > "$work/src/main/java/smoke/Hello.java" <<'JAVA'
package smoke;
public class Hello { public static void main(String[] a) { System.out.println("hello"); } }
JAVA
chmod -R a+rwX "$work"
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" --offline --no-daemon -q build 2>&1) \
  || { echo "FAIL: gradle --offline build failed: $out"; exit 1; }
[ -s "$work/build/libs/smoke.jar" ] || { echo "FAIL: build/libs/smoke.jar not produced: $out"; exit 1; }

echo "Verifying bash, apk, git and cc present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c \
  'bash --version | head -1; apk --version; git --version; cc --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All gradle-dev tests passed!"
