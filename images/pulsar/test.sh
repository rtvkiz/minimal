#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

cid=""
cleanup() {
  [ -z "$cid" ] || docker rm -f "$cid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Testing Java version..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version

echo "Testing Pulsar broker JAR present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/pulsar/lib/org.apache.pulsar-pulsar-broker-*.jar | head -1"

echo "Testing 'pulsar version' (offline, exercises the JRE + launcher)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "/opt/pulsar/bin/pulsar version" | grep -E '4\.2'

echo "Testing standalone config present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /opt/pulsar/conf/standalone.conf && echo 'config OK'"

echo "Verifying data dir is writable by nonroot (uid 65532)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "mkdir -p /var/lib/pulsar/data && touch /var/lib/pulsar/data/.probe && rm /var/lib/pulsar/data/.probe && echo 'writable OK'"

echo "Starting Pulsar standalone and waiting for broker health..."
cid=$(docker run -d \
  -e 'PULSAR_MEM=-Xms256m -Xmx512m -XX:MaxDirectMemorySize=256m' \
  "$IMAGE")
i=0
until docker exec "$cid" /bin/bash -c \
  'exec 3<>/dev/tcp/127.0.0.1/8080; printf "GET /admin/v2/brokers/health HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3; IFS= read -r status <&3; case "$status" in *" 200 "*) exit 0;; *) exit 1;; esac' 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 60 ] || [ "$(docker inspect -f '{{.State.Running}}' "$cid")" != "true" ]; then
    docker logs "$cid"
    echo "Pulsar did not become ready" >&2
    exit 1
  fi
  sleep 2
done
echo "Pulsar broker health returned HTTP 200"

echo "All Pulsar tests passed"
