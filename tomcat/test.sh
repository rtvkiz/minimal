#!/bin/bash
set -eu

: "${IMAGE:?IMAGE env var required}"

echo "Testing Java (custom JRE) ..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qiE 'openjdk|21'

echo "Testing Tomcat bootstrap present + hardened (no manager webapp) ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -f /opt/tomcat/bin/bootstrap.jar && ! test -d /opt/tomcat/webapps/manager"

echo "Testing Tomcat starts and serves :8080 ..."
cid=$(docker run -d "$IMAGE")
ok=""
for _ in $(seq 1 30); do
  if docker logs "$cid" 2>&1 | grep -qiE 'Server startup in|Starting ProtocolHandler .*http-nio-8080|Catalina.start'; then ok=1; break; fi
  sleep 1
done
echo "---- last log lines ----"; docker logs "$cid" 2>&1 | tail -4
docker rm -f "$cid" >/dev/null 2>&1 || true
[ "$ok" = 1 ] || { echo "FAIL: Tomcat did not start"; exit 1; }
echo "tomcat started OK"

echo "All tomcat tests passed!"
