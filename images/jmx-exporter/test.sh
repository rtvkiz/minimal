#!/bin/bash
# Smoke test for minimal-jmx-exporter (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing the JRE..."
jv=$(docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1)
echo "$jv" | head -1
echo "$jv" | grep -qE 'openjdk version "25\.' || { echo "FAIL: expected OpenJDK 25: $jv"; exit 1; }

echo "Testing the default fails clearly without a config..."
out=$(docker run --rm "$IMAGE" 2>&1 || true)
echo "$out" | grep -q 'FileNotFoundException: /etc/jmx_exporter/config.yaml' \
  || { echo "FAIL: unexpected default behaviour: $(echo "$out" | head -5)"; exit 1; }

work=$(mktemp -d); chmod 0755 "$work"
c1=""; c2=""
trap 'docker rm -f $c1 $c2 >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
printf 'hostPort: 127.0.0.1:5555\nrules:\n  - pattern: ".*"\n' > "$work/config.yaml"
printf 'rules:\n  - pattern: ".*"\n' > "$work/agent.yaml"
chmod 0644 "$work"/*.yaml

# Standalone (the entrypoint): scrape its OWN JVM over JMX remote — a real
# JMX/RMI round-trip with no second container.
c1=$(docker run -d -p 15556:5556 -v "$work:/etc/jmx_exporter:ro" \
  -e JAVA_TOOL_OPTIONS="-Dcom.sun.management.jmxremote.port=5555 -Dcom.sun.management.jmxremote.rmi.port=5555 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1" \
  "$IMAGE")
# javaagent: attached to jwebserver, a long-running JVM the JRE already ships.
# (The agent cannot share a JVM with the standalone jar — their shaded classes clash.)
c2=$(docker run -d -p 19404:9404 -v "$work:/etc/jmx_exporter:ro" \
  -e JAVA_TOOL_OPTIONS="-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=9404:/etc/jmx_exporter/agent.yaml" \
  --entrypoint /usr/lib/jvm/java-25-openjdk/bin/jwebserver "$IMAGE" -b 127.0.0.1 -p 8000 -d /tmp)

ok=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 http://127.0.0.1:15556/metrics >/dev/null 2>&1 \
     && curl -fsS --max-time 3 http://127.0.0.1:19404/metrics >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: exporters did not serve"; docker logs "$c1" 2>&1 | tail -15; docker logs "$c2" 2>&1 | tail -15; exit 1; }

echo "Testing standalone scraped the JVM over JMX..."
m=$(curl -fsS --max-time 5 http://127.0.0.1:15556/metrics)
echo "$m" | grep -q '^jmx_scrape_error 0' || { echo "FAIL: jmx_scrape_error is not 0"; exit 1; }
echo "$m" | grep -q '^java_lang_Memory_HeapMemoryUsage_used ' || { echo "FAIL: no MBean metrics"; exit 1; }
echo "$m" | grep -q 'jmx_exporter_build_info{name="jmx_prometheus_standalone"' || { echo "FAIL: standalone build_info missing"; exit 1; }
echo "✓ standalone JMX scrape"

echo "Testing javaagent exposes JVM metrics..."
m=$(curl -fsS --max-time 5 http://127.0.0.1:19404/metrics)
echo "$m" | grep -q '^jvm_memory_used_bytes{area="heap"}' || { echo "FAIL: agent JVM metrics missing"; exit 1; }
echo "$m" | grep -q 'jmx_exporter_build_info{name="jmx_prometheus_javaagent"' || { echo "FAIL: agent build_info missing"; exit 1; }
echo "✓ javaagent"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All jmx-exporter tests passed!"
