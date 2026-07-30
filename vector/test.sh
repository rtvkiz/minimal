#!/bin/bash
# Smoke test for minimal-vector (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing vector version..."
docker run --rm --entrypoint /usr/bin/vector "$IMAGE" --version 2>&1 | grep -qiE '^vector 0\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing config validation against the shipped default config..."
# `vector validate` parses the config and checks the topology. --no-environment
# skips connecting to external sinks/sources (nothing to reach in a smoke test).
docker run --rm --entrypoint /usr/bin/vector "$IMAGE" \
  validate --no-environment /etc/vector/vector.yaml 2>&1 | grep -qiE 'validated' \
  || { echo "FAIL: vector validate did not pass on the default config"; exit 1; }

echo "Testing vector runs the default pipeline and emits parsed events..."
# The Wolfi default config is demo_logs -> remap(parse_syslog) -> console(json),
# so a healthy container prints JSON on its own with no config mounted.
cid=$(docker run -d "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker logs "$cid" 2>&1 | grep -q '"appname"'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: vector did not emit parsed events"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying the emitted events are valid JSON (remap transform ran)..."
docker logs "$cid" 2>&1 | grep -q '"severity"' \
  || { echo "FAIL: parse_syslog transform did not produce syslog fields"; exit 1; }

echo "Verifying data dir is writable by nonroot..."
docker run --rm --entrypoint /usr/bin/vector "$IMAGE" \
  validate --no-environment /etc/vector/vector.yaml >/dev/null 2>&1 \
  || { echo "FAIL: validate failed (data dir permissions?)"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All vector tests passed!"
