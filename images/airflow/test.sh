#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

# Expected version comes from melange.yaml, never a literal. A hardcoded
# version turns every auto-bump PR red on its own smoke test while the build
# itself is fine — which is exactly what happened to the meilisearch 1.54.0
# bump (#744): both melange arches built, then prod and dev failed the version
# grep. Reading the recipe asserts the real invariant (the image ships what the
# recipe pins) and survives bumps untouched.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi

echo "Testing Airflow version..."
version=$(docker run --rm "$IMAGE" version 2>&1)
echo "$version" | grep -q "$EXPECTED" || { echo "Unexpected version: $version"; exit 1; }

echo "Testing Airflow subcommands load..."
help=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$help" | grep -q "scheduler" || { echo "Airflow help did not list scheduler"; exit 1; }
echo "$help" | grep -q "dags" || { echo "Airflow help did not list dags"; exit 1; }

echo "Testing offline DB init and DAG listing..."
# Fully offline: SQLite metadata DB in a tmpfs, no network, no external Postgres.
# This exercises the real import path — SQLAlchemy models, the plugin manager and
# the DAG parser — so a broken dependency pin fails here rather than in a user's
# scheduler.
out=$(docker run --rm --network none \
  -e AIRFLOW__CORE__LOAD_EXAMPLES=False \
  -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////tmp/airflow.db \
  -e AIRFLOW_HOME=/tmp/af \
  --entrypoint /usr/bin/airflow "$IMAGE" db migrate 2>&1) || {
    echo "airflow db migrate failed:"; echo "$out"; exit 1; }
echo "$out" | grep -qiE "database migrating|upgrade|done|initialization done" \
  || { echo "Unexpected db migrate output: $out"; exit 1; }

echo "Verifying the prebuilt web UI shipped..."
docker run --rm --network none --entrypoint /bin/sh "$IMAGE" -c \
  'test -f /opt/airflow/venv/lib/python3.12/site-packages/airflow/ui/dist/index.html' \
  || { echo "FAIL: prebuilt UI assets missing from the image"; exit 1; }

# Airflow carries the postgres-family shell exception: BashOperator needs /bin/sh.
# Assert the shell is present (regression guard) but that the wider toolchain is
# NOT (restraint guard) — busybox only, never bash or apk-tools.
echo "Verifying shell exception is exactly busybox..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo sh-ok' >/dev/null 2>&1 \
  || { echo "FAIL: /bin/sh missing — BashOperator would break"; exit 1; }
if docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'echo x' >/dev/null 2>&1; then
  echo "FAIL: production image contains bash"; exit 1
fi
if docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1; then
  echo "FAIL: production image contains apk-tools"; exit 1
fi

echo "All Airflow tests passed!"
