#!/bin/bash
set -euo pipefail

cleanup() { docker rm -f flink-test >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing Java version (custom jlink JRE)..."
# Capture before matching. `java -version | grep -q` lets grep exit at the
# first match, java takes SIGPIPE, and pipefail fails the test with 141 —
# a race that passed in prod and failed in dev from the same code.
jv=$(docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1)
echo "$jv" | grep -q "21\." || { echo "unexpected JRE: $jv"; exit 1; }

echo "Testing Flink distribution is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "test -x /opt/flink/bin/jobmanager.sh && ls /opt/flink/lib/flink-dist-*.jar" >/dev/null

echo "Testing opt/ and examples/ were dropped (image slimming held)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "test ! -d /opt/flink/opt && test ! -d /opt/flink/examples"

echo "Testing no package manager in prod..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "! command -v apk" >/dev/null

echo "Starting Flink jobmanager and waiting for its REST API..."
docker run -d --name flink-test "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 45); do
  sleep 2
  docker ps --format '{{.Names}}' | grep -q '^flink-test$' || break
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' flink-test)
  if curl -sf "http://${IP}:8081/overview" >/dev/null 2>&1; then ready=1; break; fi
done

if [ "$ready" -ne 1 ]; then
  echo "Flink jobmanager did not become ready"
  docker logs flink-test 2>&1 | tail -40 || true
  exit 1
fi

IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' flink-test)
# Capture before matching: `curl | grep -q` makes grep exit at the first match,
# curl takes SIGPIPE, and pipefail then fails the test on a working server.
overview=$(curl -sf "http://${IP}:8081/overview")
echo "$overview" | grep -q "flink-version" \
  || { echo "unexpected /overview payload: $overview"; exit 1; }
echo "  cluster reports: $(echo "$overview" | tr ',' '\n' | grep flink-version)"

echo "✓ All Flink tests passed"
