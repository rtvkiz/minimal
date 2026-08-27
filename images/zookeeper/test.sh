#!/bin/bash
set -eu  # NB: no pipefail — `docker ... | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing Java (custom JRE) ..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qiE 'openjdk|21'

echo "Testing ZooKeeper JARs present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/zookeeper/lib/zookeeper-*.jar | wc -l | grep -qvE '^0$'"

echo "Testing config present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "grep -q 'clientPort=2181' /opt/zookeeper/conf/zoo.cfg && grep -q 'dataDir=/var/zookeeper/data' /opt/zookeeper/conf/zoo.cfg"

echo "Testing server starts and binds :2181 ..."
cid=$(docker run -d -p 12181:2181 -e ZOO_HEAP_OPTS='-Xmx256M -Xms64M' "$IMAGE")
ok=""
for _ in $(seq 1 25); do
  if docker logs "$cid" 2>&1 | grep -qiE 'binding to port|Started AdminServer|Snapshotting|Created server socket|Using org.apache.zookeeper.server'; then
    ok=1; break
  fi
  sleep 1
done
echo "---- last log lines ----"; docker logs "$cid" 2>&1 | tail -4

# Four-letter-word probe over a real client connection. Startup logs prove the
# JVM got that far; `ruok` -> `imok` proves the server is actually answering on
# the client port. This matters because bundled-jar CVE patching swaps jars
# underneath ZooKeeper (jackson-databind and friends), and the whole safety
# argument for auto-patching this image is that its smoke test would catch a
# swap that breaks at runtime. `4lw.commands.whitelist` already permits ruok
# (see melange.yaml).
probe=""
for _ in $(seq 1 20); do
  if command -v bash >/dev/null 2>&1 &&
     resp=$( (exec 3<>/dev/tcp/127.0.0.1/12181 && printf 'ruok' >&3 && timeout 3 cat <&3) 2>/dev/null) &&
     [ "$resp" = "imok" ]; then
    probe=1; break
  fi
  sleep 1
done
[ -n "$probe" ] || { echo "FAIL: zookeeper did not answer ruok on :2181"; docker logs "$cid" 2>&1 | tail -20; docker rm -f "$cid" >/dev/null 2>&1; exit 1; }
echo "✓ zookeeper answered ruok -> imok"
docker rm -f "$cid" >/dev/null 2>&1 || true
[ "$ok" = 1 ] || { echo "FAIL: ZooKeeper did not start/bind"; exit 1; }
echo "zookeeper server started OK"

echo "All zookeeper tests passed!"
