#!/bin/bash
# Smoke test for minimal-gradle (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing gradle version..."
v=$(docker run --rm "$IMAGE" --version --no-daemon 2>&1)
echo "$v" | grep -qE '^Gradle [0-9]+\.[0-9]+' || { echo "FAIL: unexpected gradle --version: $v"; exit 1; }
echo "$v" | grep -qE 'Launcher JVM: +[0-9]+' || { echo "FAIL: gradle found no JVM: $v"; exit 1; }

echo "Testing gradle help..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -q -- '--offline' || { echo "FAIL: unexpected gradle --help: $h"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
# Gradle writes build/ and .gradle/ as uid 65532, which the host user cannot
# delete; clear them from inside a root container first. Cleanup must never
# decide the exit status, so both steps are non-fatal.
trap 'docker run --rm --user 0 -v "$work:/w" --entrypoint /bin/sh "$IMAGE" -c "rm -rf /w/* /w/.[!.]*" >/dev/null 2>&1 || true; rm -rf "$work" 2>/dev/null || true' EXIT

echo "Testing an offline Java build (compile + jar + run, no network)..."
# The `java` plugin ships inside Gradle, so a dependency-free project builds
# with --offline and --network none: this exercises the daemon-less launcher,
# Groovy DSL compilation, javac via the JDK toolchain and jar packaging.
mkdir -p "$work/src/main/java/smoke"
cat > "$work/settings.gradle" <<'G'
rootProject.name = 'smoke'
G
cat > "$work/build.gradle" <<'G'
plugins { id 'java' }
jar { manifest { attributes 'Main-Class': 'smoke.Hello' } }
G
cat > "$work/src/main/java/smoke/Hello.java" <<'JAVA'
package smoke;
public class Hello { public static void main(String[] a) { System.out.println("hello-from-gradle"); } }
JAVA
chmod -R a+rwX "$work"
out=$(docker run --rm --network none -v "$work:/app" "$IMAGE" --offline --no-daemon -q build 2>&1) \
  || { echo "FAIL: gradle --offline build failed: $out"; exit 1; }
[ -s "$work/build/libs/smoke.jar" ] || { echo "FAIL: build/libs/smoke.jar not produced: $out"; exit 1; }
run=$(docker run --rm --network none -v "$work:/app" --entrypoint /usr/lib/jvm/default-jvm/bin/java "$IMAGE" -jar build/libs/smoke.jar 2>&1)
echo "$run" | grep -q 'hello-from-gradle' || { echo "FAIL: built jar did not run: $run"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying shell is busybox only (gradle's launcher-script exception, no bash/apk)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo shell-ok" 2>&1 | grep -q 'shell-ok' \
  || { echo "FAIL: expected busybox /bin/sh to be present"; exit 1; }
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: bash found — restraint guard violated"; exit 1; } \
  || echo "No bash (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All gradle tests passed!"
