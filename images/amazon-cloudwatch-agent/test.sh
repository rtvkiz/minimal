#!/bin/bash
# Smoke test for minimal-amazon-cloudwatch-agent (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

CW=/opt/aws/amazon-cloudwatch-agent
net="cwagent-test-$$"
cleanup() { docker rm -f "$net-a" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing agent version..."
v=$(docker run --rm --network none --entrypoint "$CW/bin/amazon-cloudwatch-agent" "$IMAGE" -version 2>&1 || true)
echo "$v" | grep -qE '^CWAgent/1\.[0-9]+\.[0-9]+ ' || { echo "FAIL: unexpected -version: $v"; exit 1; }

echo "Testing the upstream entrypoint path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = "[\"$CW/bin/start-amazon-cloudwatch-agent\"]" ] || { echo "FAIL: entrypoint is $ep"; exit 1; }

echo "Testing a missing config fails cleanly at translation..."
out=$(timeout 60 docker run --rm --network none "$IMAGE" 2>&1 || true)
echo "$out" | grep -q 'Cannot translate JSON' || { echo "FAIL: unexpected output without config:"; echo "$out" | tail -5; exit 1; }

echo "Starting the agent with a CW_CONFIG_CONTENT config (statsd receiver)..."
# Same config path as upstream's container: start-amazon-cloudwatch-agent runs
# config-translator (JSON -> TOML/YAML written into etc/ as nonroot) and then
# execs the agent. No EC2 metadata here, so it waits ~30s for it before going on.
docker network create --internal "$net" >/dev/null
docker run -d --name "$net-a" --network "$net" \
  -e CW_CONFIG_CONTENT='{"agent":{"region":"us-east-1","debug":true},"metrics":{"metrics_collected":{"statsd":{"service_address":":8125"}}}}' \
  "$IMAGE" >/dev/null
ok=""
for _ in $(seq 1 120); do
  docker logs "$net-a" 2>&1 | grep -q '"otelcol.component.id":"telegraf_statsd"' && { ok=1; break; }
  [ "$(docker inspect -f '{{.State.Status}}' "$net-a")" = running ] || break
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: statsd receiver never started"; docker logs "$net-a" 2>&1 | grep -v 'Sleep until network' | tail -15; exit 1; }

echo "Testing the translator output landed in etc/ (writable by nonroot)..."
listing=$(docker cp "$net-a:$CW/etc" - 2>/dev/null | tar t)
for f in etc/amazon-cloudwatch-agent.toml etc/amazon-cloudwatch-agent.yaml etc/env-config.json; do
  echo "$listing" | grep -qxF "$f" || { echo "FAIL: translator did not write $f"; echo "$listing"; exit 1; }
done
docker logs "$net-a" 2>&1 | grep -qiE 'permission denied' && { echo "FAIL: permission error"; docker logs "$net-a" 2>&1 | grep -i 'permission denied' | head -3; exit 1; } || true

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All amazon-cloudwatch-agent tests passed!"
