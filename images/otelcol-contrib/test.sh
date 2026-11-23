#!/bin/bash
# Smoke test for minimal-otelcol-contrib (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

net="otelc-test-$$"
work=$(mktemp -d); chmod 0755 "$work"
cleanup() { docker rm -f "$net-c" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

echo "Testing collector version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 || true)
echo "$v" | grep -qE '^otelcontribcol version 0\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected --version: $v"; exit 1; }

echo "Testing the contrib component set is present (not the core distribution)..."
comps=$(docker run --rm --network none "$IMAGE" components 2>&1 || true)
for c in prometheus file_log k8s_attributes awsxray load_balancing transform; do
  echo "$comps" | grep -qE "^\s+- name: $c\$" || { echo "FAIL: contrib component '$c' missing"; exit 1; }
done

echo "Testing the upstream entrypoint and default config path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}' "$IMAGE")
[ "$ep" = '["/otelcol-contrib"] ["--config=/etc/otelcol-contrib/config.yaml"]' ] || { echo "FAIL: entrypoint/cmd is $ep"; exit 1; }

echo "Testing a missing config fails fast with a clear error..."
out=$(timeout 30 docker run --rm --network none "$IMAGE" 2>&1 || true)
echo "$out" | grep -q 'unable to read the file file:/etc/otelcol-contrib/config.yaml' \
  || { echo "FAIL: unexpected output with no config: $out"; exit 1; }

echo "Running a mounted pipeline (OTLP in -> transform -> debug out)..."
# Mounted at upstream's path with no extra args - the common way to run the
# upstream image. The transform processor is contrib-only, so this pipeline
# cannot load on the core distribution.
cat > "$work/config.yaml" <<'YAML'
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
processors:
  transform:
    trace_statements:
      - context: span
        statements:
          - set(attributes["smoke.tagged"], "yes")
exporters:
  debug:
    verbosity: detailed
service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [transform]
      exporters: [debug]
YAML
chmod 0644 "$work/config.yaml"
docker network create --internal "$net" >/dev/null
docker run -d --name "$net-c" --network "$net" -v "$work/config.yaml:/etc/otelcol-contrib/config.yaml:ro" "$IMAGE" >/dev/null
ok=""
for _ in $(seq 1 30); do
  docker run --rm --network "$net" busybox:stable wget -q --spider "http://$net-c:13133/" 2>/dev/null && { ok=1; break; }
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: health_check never ready"; docker logs "$net-c" 2>&1 | tail -15; exit 1; }

echo "Testing an OTLP/HTTP span is received, transformed and exported..."
span='{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"smoke-svc"}}]},"scopeSpans":[{"spans":[{"traceId":"5b8efff798038103d269b633813fc60c","spanId":"eee19b7ec3c1b174","name":"smoke-span","kind":1,"startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000001000000000"}]}]}]}'
docker run --rm --network "$net" busybox:stable wget -qO- --header 'Content-Type: application/json' \
  --post-data "$span" "http://$net-c:4318/v1/traces" >/dev/null || { echo "FAIL: OTLP POST rejected"; docker logs "$net-c" 2>&1 | tail -10; exit 1; }
ok=""
for _ in $(seq 1 20); do
  logs=$(docker logs "$net-c" 2>&1)
  echo "$logs" | grep -q 'smoke-span' && echo "$logs" | grep -q 'smoke.tagged: Str(yes)' && { ok=1; break; }
  sleep 0.5
done
[ -n "$ok" ] || { echo "FAIL: span not exported with the transform applied"; docker logs "$net-c" 2>&1 | tail -20; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All otelcol-contrib tests passed!"
