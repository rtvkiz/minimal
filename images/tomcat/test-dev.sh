#!/bin/bash
set -eu
: "${IMAGE:?IMAGE env var required}"
echo "Testing Java (parity) ..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -qiE 'openjdk|21'
echo "Testing bootstrap present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -f /opt/tomcat/bin/bootstrap.jar"
echo "Testing /bin/sh + /bin/bash ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok
echo "Testing curl/openssl/jq present ..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null"
echo "✓ All tomcat-dev smoke tests passed"
