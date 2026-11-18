#!/bin/bash
# Smoke test for minimal-groovy (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing groovy version is $EXPECTED on OpenJDK 25..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -q "Groovy Version: ${EXPECTED} " || { echo "FAIL: unexpected groovy --version: $v"; exit 1; }
echo "$v" | grep -qE 'JVM: 25\.' || { echo "FAIL: expected JVM 25: $v"; exit 1; }

echo "Testing an inline expression..."
out=$(docker run --rm --network none "$IMAGE" -e 'println([3, 1, 2].sort().collect { it * 2 }.join(","))' 2>&1)
[ "$out" = "2,4,6" ] || { echo "FAIL: inline expression: $out"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT

echo "Testing a script file using classes, closures and bundled modules (no network)..."
# groovy.json and groovy.xml live in separate jars under lib/: this fails if
# the lib/* classpath only picked up the core jar.
cat > "$work/smoke.groovy" <<'GROOVY'
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import groovy.xml.XmlSlurper

class Item { String name; int qty }
def items = [new Item(name: 'a', qty: 2), new Item(name: 'b', qty: 3)]
def json = JsonOutput.toJson(items.collectEntries { [(it.name): it.qty] })
def back = new JsonSlurper().parseText(json)
def xml = new XmlSlurper().parseText('<r><v>7</v></r>')
println "groovy-script-ok ${back.a + back.b} ${xml.v.text()}"
GROOVY
chmod 0644 "$work/smoke.groovy"
out=$(docker run --rm --network none -v "$work:/work" "$IMAGE" smoke.groovy 2>&1)
[ "$out" = "groovy-script-ok 5 7" ] || { echo "FAIL: script output: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found"; exit 1; } || echo "No apk (as expected)"

echo "All groovy tests passed!"
