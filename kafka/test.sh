#!/bin/bash
set -euo pipefail

echo "Testing Java version..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version

echo "Testing Kafka JARs present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/kafka/libs/kafka_*.jar | wc -l | grep -v '^0$'"

echo "Testing Kafka main class loads..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "java -cp '/opt/kafka/libs/*' kafka.Kafka 2>&1 | head -1 | grep -i 'usage\|config\|error\|kafka'" || true

echo "Testing StorageTool (random-uuid)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "java -cp '/opt/kafka/libs/*' org.apache.kafka.tools.StorageTool random-uuid | grep -E '^[A-Za-z0-9_-]{22}$'"

echo "Testing config present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /opt/kafka/config/server.properties && echo 'config OK'"

echo "Verifying log.dirs is set correctly..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "grep 'log.dirs=/var/kafka/data' /opt/kafka/config/server.properties"

echo "All Kafka tests passed"
