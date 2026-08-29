#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing java runtime..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qE 'openjdk version "21'

echo "Booting Zipkin and probing /health..."
# Full runtime probe. Exercises the exploded Spring Boot launch, the jlink
# module set, and the in-memory storage backend. This is also the safety net
# that lets bundled-jar swaps run in `auto` policy: a swap that breaks the
# classpath fails CI here instead of shipping.
CID=$(docker run -d --rm -p 19411:9411 "$IMAGE")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 http://127.0.0.1:19411/health 2>/dev/null | grep -q '"status"'; then
    ok=1; break
  fi
  docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null | grep -q true || break
  sleep 2
done
[ -n "$ok" ] || { echo "FAIL: Zipkin did not become healthy"; docker logs "$CID" 2>&1 | tail -40; exit 1; }

curl -fsS --max-time 5 http://127.0.0.1:19411/health | grep -q '"status" : "UP"' \
  || { echo "FAIL: /health did not report UP"; exit 1; }
echo "Zipkin /health UP"

echo "Testing the trace query API..."
curl -fsS --max-time 5 http://127.0.0.1:19411/api/v2/services | grep -q '\[' \
  || { echo "FAIL: /api/v2/services did not return JSON"; exit 1; }
echo "Zipkin query API OK"

echo "Testing span ingestion round-trip..."
# POST a span, then read it back by service name — proves the collector,
# storage backend and query API are all actually wired, not just listening.
curl -fsS --max-time 5 -X POST http://127.0.0.1:19411/api/v2/spans \
  -H 'Content-Type: application/json' \
  -d '[{"traceId":"1111111111111111","id":"2222222222222222","name":"smoke","timestamp":1600000000000000,"duration":1000,"localEndpoint":{"serviceName":"smoketest"}}]' \
  >/dev/null

found=""
for _ in $(seq 1 15); do
  if curl -fsS --max-time 5 http://127.0.0.1:19411/api/v2/services | grep -q 'smoketest'; then
    found=1; break
  fi
  sleep 1
done
[ -n "$found" ] || { echo "FAIL: ingested span never appeared in /api/v2/services"; docker logs "$CID" 2>&1 | tail -20; exit 1; }
echo "Zipkin span ingestion round-trip OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All zipkin tests passed!"
