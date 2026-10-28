#!/bin/bash
# Smoke test for minimal-cadvisor (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing cadvisor version..."
ver=$(docker run --rm "$IMAGE" --version 2>&1 || true)
echo "$ver" | grep -qE 'cAdvisor version v[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing cadvisor serves /metrics (offline)..."
cid=$(docker run -d -p 18080:8080 "$IMAGE" )
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:18080/metrics >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: cadvisor did not serve /metrics"; docker logs "$cid" 2>&1 | tail -20; exit 1; }
body=$(curl -fsS --max-time 5 http://127.0.0.1:18080/metrics)
echo "$body" | grep -qE '^cadvisor_version_info' \
  || { echo "FAIL: cadvisor_version_info metric missing from response"; exit 1; }
echo "✓ cadvisor_version_info metric"
echo "$body" | grep -qE '^machine_cpu_cores' \
  || { echo "FAIL: machine_cpu_cores metric missing from response"; exit 1; }
echo "✓ machine_cpu_cores metric"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All cadvisor tests passed!"
