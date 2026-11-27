#!/bin/bash
# Smoke test for minimal-crate (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

name="minimal-crate-smoke-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "Starting a single node with the default CMD..."
docker run -d --name "$name" -p 127.0.0.1::4200 -p 127.0.0.1::5432 -e JAVA_TOOL_OPTIONS=-Xmx512m "$IMAGE" >/dev/null
http=$(docker port "$name" 4200/tcp | head -1)
# Probe from inside the container's network namespace: the shipped auth config
# only trusts localhost (see below), so a host-side probe gets refused.
CURL_IMAGE="${CURL_IMAGE:-ghcr.io/rtvkiz/minimal-curl:latest}"
local_curl() { docker run --rm --network "container:$name" "$CURL_IMAGE" -sf --max-time 10 "$@"; }
root=""
for i in $(seq 1 120); do
  root=$(local_curl http://127.0.0.1:4200/ 2>/dev/null) && break
  sleep 1
done
echo "$root" | grep -q '"number"' || { echo "FAIL: HTTP endpoint never answered: ${root:-none}"; docker logs "$name" 2>&1 | tail -30; exit 1; }
echo "Version: $(echo "$root" | grep -oE '"number" *: *"[^"]+"' | head -1)"

# CrateDB's shipped crate.yml (kept as-is, as upstream) trusts the `crate`
# superuser from localhost only. So SQL runs from inside the container's
# network namespace, via minimal-curl, and a remote superuser request must be
# refused.
sql() { docker run --rm --network "container:$name" "$CURL_IMAGE" -sf --max-time 30 \
          -H 'Content-Type: application/json' -d "{\"stmt\":\"$1\"}" http://127.0.0.1:4200/_sql; }
echo "Testing SQL over HTTP as crate from localhost, including a write to the data directory..."
out=$(sql "select 1 + 1") || { echo "FAIL: select"; exit 1; }
echo "$out" | grep -q '"rows":\[\[2\]\]' || { echo "FAIL: select 1+1: $out"; exit 1; }
sql "create table smoke (id int primary key, name text)" >/dev/null || { echo "FAIL: create table"; exit 1; }
sql "insert into smoke (id, name) values (1, 'ok')" >/dev/null || { echo "FAIL: insert"; exit 1; }
sql "refresh table smoke" >/dev/null
out=$(sql "select name from smoke where id = 1")
echo "$out" | grep -q '"rows":\[\["ok"\]\]' || { echo "FAIL: read back: $out"; exit 1; }

echo "Verifying the superuser is refused from outside the container (secure default)..."
remote=$(curl -s --max-time 10 -H 'Content-Type: application/json' -d '{"stmt":"select 1"}' "http://$http/_sql")
echo "$remote" | grep -q 'No valid auth.host_based.config entry' \
  || { echo "FAIL: remote superuser was not refused: $remote"; exit 1; }

echo "Testing the PostgreSQL wire port accepts connections..."
pg=$(docker port "$name" 5432/tcp | head -1)
(exec 3<>"/dev/tcp/${pg%:*}/${pg##*:}") 2>/dev/null || { echo "FAIL: pg wire port $pg not accepting"; exit 1; }

echo "Verifying it runs on Wolfi's JRE, not a bundled JDK..."
docker run --rm --entrypoint /usr/lib/jvm/java-26-openjdk/bin/java "$IMAGE" -version 2>&1 | grep -q 'OpenJDK' \
  || { echo "FAIL: Wolfi openjdk-26 not runnable"; exit 1; }
docker run --rm --entrypoint /usr/share/crate/jdk/bin/java "$IMAGE" -version >/dev/null 2>&1 \
  && { echo "FAIL: bundled JDK still present"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell and no package manager..."
for f in /bin/sh /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "None present (as expected)"

echo "All crate tests passed!"
