#!/bin/bash
# Smoke test for minimal-falcosidekick (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

net="fsk-test-$$"
cleanup() { docker rm -f "$net-srv" "$net-hook" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing falcosidekick version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 || true)
echo "$v" | grep -qE '^GitVersion:\s+[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected --version: $v"; exit 1; }
echo "$v" | grep -qE '^GitVersion:\s+(devel|unknown)?$' && { echo "FAIL: version not injected"; exit 1; } || true

echo "Starting a webhook receiver and falcosidekick on a private network..."
# busybox httpd + a CGI script that records the POST body: a real HTTP
# endpoint, no internet access needed.
docker network create --internal "$net" >/dev/null
docker run -d --name "$net-hook" --network "$net" busybox:stable sh -c '
  mkdir -p /www/cgi-bin
  printf "#!/bin/sh\ncat > /tmp/body\nprintf \"Content-Type: text/plain\\r\\n\\r\\nok\"\n" > /www/cgi-bin/hook
  chmod +x /www/cgi-bin/hook
  exec httpd -f -p 9000 -h /www' >/dev/null
docker run -d --name "$net-srv" --network "$net" \
  -e WEBHOOK_ADDRESS="http://$net-hook:9000/cgi-bin/hook" "$IMAGE" >/dev/null

hc=""
for _ in $(seq 1 30); do
  hc=$(docker run --rm --network "$net" busybox:stable wget -qO- "http://$net-srv:2801/healthz" 2>/dev/null) && break
  sleep 0.5
done
echo "$hc" | grep -q '"status": *"ok"' || { echo "FAIL: /healthz: '$hc'"; docker logs "$net-srv" 2>&1 | tail -10; exit 1; }

echo "Testing a Falco event is forwarded to the webhook output..."
docker run --rm --network "$net" busybox:stable wget -qO- --header 'Content-Type: application/json' \
  --post-data '{"output":"smoke event","priority":"Critical","rule":"Smoke Rule","time":"2026-11-21T00:00:00.000000000Z","output_fields":{"proc.name":"bash"}}' \
  "http://$net-srv:2801/" >/dev/null || { echo "FAIL: event POST rejected"; exit 1; }
ok=""
for _ in $(seq 1 20); do
  docker logs "$net-srv" 2>&1 | grep -q 'Webhook - POST OK (200)' && { ok=1; break; }
  sleep 0.5
done
[ -n "$ok" ] || { echo "FAIL: webhook never delivered"; docker logs "$net-srv" 2>&1 | tail -10; exit 1; }
body=$(docker exec "$net-hook" cat /tmp/body)
echo "$body" | grep -q '"rule":"Smoke Rule"' || { echo "FAIL: webhook got the wrong body: $body"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All falcosidekick tests passed!"
