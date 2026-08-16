#!/bin/bash
# Smoke test for minimal-patroni (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing patroni version..."
docker run --rm --entrypoint /usr/bin/patroni "$IMAGE" --version 2>&1 | grep -qiE '^patroni 4\.' \
  || { echo "FAIL: patroni version string not found"; exit 1; }

echo "Testing patronictl version..."
docker run --rm --entrypoint /usr/bin/patronictl "$IMAGE" version 2>&1 | grep -qiE 'patronictl version 4\.' \
  || { echo "FAIL: patronictl version string not found"; exit 1; }

echo "Testing the managed PostgreSQL server is present..."
# Patroni is a supervisor — without the server binaries it can only act as a
# patronictl client, so the postgres major version is part of the contract.
docker run --rm --entrypoint /usr/bin/postgres "$IMAGE" --version 2>&1 | grep -qiE 'PostgreSQL\) 18\.' \
  || { echo "FAIL: postgres 18 not found in image"; exit 1; }

echo "Testing sample config generation (proves the Python import graph resolves)..."
# The whole py3.13-{psycopg,pysyncobj,boto3,click,prettytable,ydiff} dependency
# graph is exercised here; a missing module fails this outright.
docker run --rm --entrypoint /usr/bin/patroni "$IMAGE" --generate-sample-config 2>/dev/null \
  | grep -qE '^scope:' \
  || { echo "FAIL: --generate-sample-config produced no usable config"; exit 1; }

echo "Testing initdb can bootstrap a cluster as nonroot (offline)..."
# REGRESSION GUARD: initdb runs `"postgres" -V` via popen(), which needs /bin/sh.
# A shell-less image fails here with ENOENT and Patroni can never bootstrap.
# This is why prod carries busybox — if the shell is ever dropped, this fails.
docker run --rm --tmpfs /pgtest:uid=65532,gid=65532,mode=0700 \
  --entrypoint /usr/bin/initdb "$IMAGE" -D /pgtest -U postgres --auth=trust 2>&1 \
  | grep -qi 'Success' \
  || { echo "FAIL: initdb could not bootstrap a data dir (missing /bin/sh?)"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying prod restraint: shell is busybox-only, no bash/apk-tools..."
# Prod deliberately carries a shell (see above) but must NOT carry the dev
# toolchain. Keep the blast radius to busybox.
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: /bin/sh missing — initdb will break"; exit 1; }
for forbidden in /bin/bash /usr/bin/bash /sbin/apk /usr/bin/apk; do
  docker run --rm --entrypoint "$forbidden" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $forbidden present in prod image"; exit 1; }
done
echo "busybox sh only (as expected)"

echo "All patroni tests passed!"
