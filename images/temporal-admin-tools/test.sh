#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

# This image is a toolbox, not a service: upstream runs it as
# `tini -- sleep infinity` and you exec in to run the schema tools by hand.
# A shell is therefore REQUIRED here, unlike every service image in this repo.
# That is a deliberate exception, so it is tested in both directions — the
# shell must exist, and the extras must NOT creep in (the postgres-slim pattern).
echo "Testing the admin toolbox binaries are all present..."
for b in tdbg temporal-cassandra-tool temporal-sql-tool temporal-elasticsearch-tool \
         temporal tctl tctl-authorization-plugin; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -x /usr/bin/$b" \
    || { echo "FAIL: /usr/bin/$b missing"; exit 1; }
done

echo "Testing the tools actually run..."
docker run --rm --entrypoint /usr/bin/temporal "$IMAGE" --version 2>&1 | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: temporal CLI version not injected"; exit 1; }
docker run --rm --entrypoint /usr/bin/tctl "$IMAGE" --version 2>&1 | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: tctl version not stamped"; exit 1; }
docker run --rm --entrypoint /usr/bin/temporal-sql-tool "$IMAGE" --help >/dev/null 2>&1 \
  || { echo "FAIL: temporal-sql-tool did not run"; exit 1; }

echo "Testing schema files are shipped..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "test -d /etc/temporal/schema/cassandra && test -d /etc/temporal/schema/mysql" \
  || { echo "FAIL: /etc/temporal/schema incomplete"; exit 1; }

echo "Testing the shell IS present (required: this image is exec-ed into)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok \
  || { echo "FAIL: no /bin/sh — the toolbox is unusable without one"; exit 1; }

echo "Testing restraint: no package manager in the toolbox..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v apk" >/dev/null 2>&1; then
  echo "FAIL: apk-tools present — prod must not ship a package manager"; exit 1
fi
echo "Shell present, package manager absent (as intended)"

echo "✓ All temporal-admin-tools tests passed"
