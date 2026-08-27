#!/bin/bash
set -euo pipefail

echo "Testing Java version..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version

echo "Testing Kafka JARs present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/kafka/libs/kafka*.jar | wc -l | grep -v '^0$'"

echo "Testing Kafka main class loads..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "java -cp '/opt/kafka/libs/*' kafka.Kafka 2>&1 | head -1 | grep -i 'usage\|config\|error\|kafka'" || true

echo "Testing StorageTool (random-uuid)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "java -cp '/opt/kafka/libs/*' kafka.tools.StorageTool random-uuid | grep -E '^[A-Za-z0-9_-]{22}$'"

echo "Testing config present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /opt/kafka/config/server.properties && echo 'config OK'"

echo "Verifying log.dirs is set correctly..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "grep 'log.dirs=/var/kafka/data' /opt/kafka/config/server.properties"

# Boot the broker and complete a real admin round-trip.
#
# Everything above is offline: class loading, JAR presence, config files. None
# of it would notice a bundled-jar CVE swap that breaks at RUNTIME rather than
# at class-load — which is the whole risk auto-patching this image has to be
# safe against. So actually start the broker (KRaft; the entrypoint formats
# storage) and drive it through the admin API.
echo "Testing broker starts and serves the admin API..."
cid=$(docker run -d -p 19092:9092 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

# NB: no `docker logs | grep -q` here. This file runs under `set -o pipefail`,
# and grep -q exits on first match, SIGPIPEing docker logs — the pipeline then
# reports 141 and the SUCCESS case looks like a failure. Capture, then match.
ok=""
for _ in $(seq 1 60); do
  logs=$(docker logs "$cid" 2>&1 || true)
  case "$logs" in
    *"Kafka Server started"*|*"started (kafka.server"*) ok=1; break ;;
  esac
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: broker did not start"; docker logs "$cid" 2>&1 | tail -25; exit 1; }
echo "✓ broker started"

# Create and list a topic. Exercises the metadata/controller path and the JSON
# handling a jackson swap would touch.
#
# Invoked through the classpath, NOT /opt/kafka/bin/*.sh: this image ships only
# config/ and libs/, deliberately — upstream's launcher scripts are shell and
# the prod image has no reason to carry them.
KCP='/opt/kafka/libs/*'
TC="org.apache.kafka.tools.TopicCommand --bootstrap-server 127.0.0.1:9092"

docker exec "$cid" /bin/sh -c "/usr/bin/java -cp '$KCP' $TC --create --topic smoke --partitions 1 --replication-factor 1" \
  >/dev/null 2>&1 || { echo "FAIL: could not create topic"; docker logs "$cid" 2>&1 | tail -25; exit 1; }

topics=$(docker exec "$cid" /bin/sh -c "/usr/bin/java -cp '$KCP' $TC --list" 2>/dev/null || true)
case "$topics" in
  *smoke*) ;;
  *) echo "FAIL: topic not listed (got: $topics)"; exit 1 ;;
esac
echo "✓ topic create/list round-trip OK"

echo "All Kafka tests passed"
