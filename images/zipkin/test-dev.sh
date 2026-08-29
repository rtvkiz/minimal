#!/bin/bash
# Smoke test for minimal-zipkin-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing java runtime (parity with prod)..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qE 'openjdk version "21'

echo "Testing exploded layout (bundled jars are real files on disk)..."
# The dev variant HAS a shell, so it can assert directly what prod can only
# prove indirectly by booting: the fat jar was unpacked, so syft and the
# bundled-jar patcher can see every dependency.
n=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'ls /opt/zipkin/BOOT-INF/lib/*.jar | wc -l')
echo "  bundled jars: $n"
[ "$n" -gt 100 ] || { echo "FAIL: only $n bundled jars — fat jar not exploded?"; exit 1; }
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c 'test -f /opt/zipkin/org/springframework/boot/loader/launch/JarLauncher.class'

echo "Booting Zipkin and probing /health (parity with prod)..."
CID=$(docker run -d --rm -p 19412:9411 "$IMAGE")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT
ok=""
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 http://127.0.0.1:19412/health 2>/dev/null | grep -q '"status" : "UP"'; then
    ok=1; break
  fi
  docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null | grep -q true || break
  sleep 2
done
[ -n "$ok" ] || { echo "FAIL: Zipkin did not become healthy"; docker logs "$CID" 2>&1 | tail -40; exit 1; }
echo "Zipkin /health UP"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing curl/openssl/jq present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"

echo "All zipkin-dev tests passed!"
