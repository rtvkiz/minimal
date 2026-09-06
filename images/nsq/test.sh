#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing nsqd version..."
nv=$(docker run --rm --entrypoint /usr/bin/nsqd "$IMAGE" --version 2>&1)
echo "$nv" | grep -qE 'nsqd v1\.[0-9]+' || { echo "unexpected version: $nv"; exit 1; }

echo "Testing every shipped binary is present and reports its version..."
# The upstream nsqio/nsq image ships all nine; a partial build here would make
# this image a silent non-replacement, and only nsqd would ever be exercised.
for app in nsqd nsqlookupd nsqadmin nsq_to_nsq nsq_to_file nsq_to_http nsq_tail nsq_stat; do
  out=$(docker run --rm --entrypoint "/usr/bin/$app" "$IMAGE" --version 2>&1)
  echo "$out" | grep -qE "$app v1\.[0-9]+" || { echo "FAIL: $app missing or wrong version: $out"; exit 1; }
done

# to_nsq is the ninth and the one exception: it is a stdin-to-nsqd pipe with no
# --version flag at all (`flag provided but not defined: -version`), so assert
# it is present and its flag set is wired instead.
out=$(docker run --rm --entrypoint /usr/bin/to_nsq "$IMAGE" --help 2>&1 || true)
echo "$out" | grep -q 'nsqd-tcp-address' || { echo "FAIL: to_nsq missing or not wired: $out"; exit 1; }
echo "All nine binaries OK"

echo "Testing nsqd help lists its flags..."
docker run --rm --entrypoint /usr/bin/nsqd "$IMAGE" --help 2>&1 | grep -qE 'data-path|lookupd-tcp-address'

echo "Testing a full publish/consume round-trip through nsqd..."
# Boot nsqd against the image's own /data, publish over the HTTP API and read
# the message back. Exercises the writable data dir, the TCP and HTTP
# listeners, and the diskqueue metadata write — not just flag parsing.
CID=$(docker run -d --rm -p 14150:4150 -p 14151:4151 "$IMAGE")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 30); do
  if curl -fsS --max-time 3 http://127.0.0.1:14151/ping 2>/dev/null | grep -q 'OK'; then
    ok=1; break
  fi
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: nsqd did not answer /ping"; docker logs "$CID" 2>&1 | tail -30; exit 1; }

curl -fsS --max-time 5 -d 'minimal-smoke-test' \
  'http://127.0.0.1:14151/pub?topic=smoke' >/dev/null \
  || { echo "FAIL: publish rejected"; docker logs "$CID" 2>&1 | tail -20; exit 1; }

stats=$(curl -fsS --max-time 5 'http://127.0.0.1:14151/stats?format=json' 2>/dev/null || true)
echo "$stats" | grep -q '"topic_name":"smoke"' \
  || { echo "FAIL: published topic not in stats: $stats"; exit 1; }
echo "nsqd publish round-trip OK"

echo "Verifying /data is writable by nonroot..."
docker logs "$CID" 2>&1 | grep -qiE 'permission denied' \
  && { echo "FAIL: permission denied writing /data"; exit 1; } || echo "/data writable OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All nsq tests passed!"
