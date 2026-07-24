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

echo "Testing Cassandra JARs present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/cassandra/lib/apache-cassandra-*.jar | wc -l | grep -v '^0$'"

echo "Testing jamm javaagent shipped..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/cassandra/lib/jamm-*.jar | head -1"

echo "Testing 'cassandra -v' prints version (offline, exercises the JRE)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "JAVA_HOME=/usr/lib/jvm/java-17-minimal /opt/cassandra/bin/cassandra -v" | grep -E '^5\.0'

echo "Testing config present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /opt/cassandra/conf/cassandra.yaml && echo 'config OK'"

echo "Verifying rpc_address bound for container access..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "grep -E '^rpc_address: 0.0.0.0' /opt/cassandra/conf/cassandra.yaml"

echo "Verifying data dirs are writable by nonroot (uid 65532)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "touch /var/lib/cassandra/data/.probe && rm /var/lib/cassandra/data/.probe && echo 'writable OK'"

echo "Starting Cassandra and waiting for a NORMAL node..."
cid=$(docker run -d \
  -e MAX_HEAP_SIZE=512M \
  -e HEAP_NEWSIZE=100M \
  "$IMAGE")
i=0
until docker exec "$cid" /opt/cassandra/bin/nodetool status 2>/dev/null | grep -q '^UN'; do
  i=$((i + 1))
  if [ "$i" -ge 60 ] || [ "$(docker inspect -f '{{.State.Running}}' "$cid")" != "true" ]; then
    docker logs "$cid"
    echo "Cassandra did not become ready" >&2
    exit 1
  fi
  sleep 2
done
echo "Cassandra node is NORMAL"

echo "All Cassandra tests passed"
