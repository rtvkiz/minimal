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
cid=$(docker run -d -e ZOO_HEAP_OPTS='-Xmx256M -Xms64M' "$IMAGE")
ok=""
for _ in $(seq 1 25); do
  if docker logs "$cid" 2>&1 | grep -qiE 'binding to port|Started AdminServer|Snapshotting|Created server socket|Using org.apache.zookeeper.server'; then
    ok=1; break
  fi
  sleep 1
done
echo "---- last log lines ----"; docker logs "$cid" 2>&1 | tail -4
docker rm -f "$cid" >/dev/null 2>&1 || true
[ "$ok" = 1 ] || { echo "FAIL: ZooKeeper did not start/bind"; exit 1; }
echo "zookeeper server started OK"

echo "All zookeeper tests passed!"
