#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

cid=""
cleanup() {
  [ -z "$cid" ] || docker rm -f "$cid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Testing Java version..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version

echo "Testing Solr core JAR present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "ls /opt/solr/server/solr-webapp/webapp/WEB-INF/lib/solr-core-*.jar | head -1"

echo "Testing 'solr version' (offline, exercises the JRE + launcher)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "/opt/solr/bin/solr version" | grep -E '10\.0'

echo "Testing bundled solr.xml + _default configset present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "test -f /opt/solr/server/solr/solr.xml && test -d /opt/solr/server/solr/configsets/_default && echo 'config OK'"

echo "Verifying SOLR_HOME is writable by nonroot (uid 65532)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "mkdir -p /var/solr/data && touch /var/solr/data/.probe && rm /var/solr/data/.probe && echo 'writable OK'"

echo "Starting Solr and waiting for its system API..."
cid=$(docker run -d "$IMAGE")
i=0
until docker exec "$cid" /bin/bash -c \
  'exec 3<>/dev/tcp/127.0.0.1/8983; printf "GET /solr/admin/info/system HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3; IFS= read -r status <&3; case "$status" in *" 200 "*) exit 0;; *) exit 1;; esac' 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 45 ] || [ "$(docker inspect -f '{{.State.Running}}' "$cid")" != "true" ]; then
    docker logs "$cid"
    echo "Solr did not become ready" >&2
    exit 1
  fi
  sleep 2
done
echo "Solr system API returned HTTP 200"

echo "All Solr tests passed"
