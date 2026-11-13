#!/bin/bash
# Smoke test for minimal-azure-cli (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing az version (expect $EXPECTED)..."
v=$(docker run --rm --network none "$IMAGE" version --output json 2>&1)
echo "$v" | grep -qF "\"azure-cli\": \"$EXPECTED\"" || { echo "FAIL: unexpected az version: $v"; exit 1; }

echo "Testing az help and a command module loads..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1)
echo "$h" | grep -q 'Subgroups' || { echo "FAIL: unexpected az --help: $h"; exit 1; }
g=$(docker run --rm --network none "$IMAGE" group create --help 2>&1)
echo "$g" | grep -q -- '--location' || { echo "FAIL: resource module did not load: $g"; exit 1; }

echo "Testing an offline config round-trip (writes \$HOME/.azure)..."
# A named volume, not a bind mount: az writes its config as uid 65532, which
# the host user cannot delete, and the image has no shell to clean up with.
vol="minimal-azure-cli-smoke-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
docker run --rm --network none -v "$vol:/tmp/.azure" "$IMAGE" config set core.output=yamlc >/dev/null 2>&1 \
  || { echo "FAIL: az config set failed"; exit 1; }
c=$(docker run --rm --network none -v "$vol:/tmp/.azure" "$IMAGE" config get core.output --output json 2>&1)
echo "$c" | grep -q '"value": "yamlc"' || { echo "FAIL: config did not round-trip: $c"; exit 1; }

echo "Testing an unauthenticated call is handled (login prompt, no traceback)..."
# Without a login az exits 0 with a warning and an empty list; what this
# guards is the profile/auth stack (msal, azure-identity) importing cleanly.
set +e
a=$(docker run --rm --network none "$IMAGE" account list 2>&1)
set -e
echo "$a" | grep -q "az login" || { echo "FAIL: expected a login prompt: $a"; exit 1; }
if echo "$a" | grep -q "Traceback"; then echo "FAIL: az crashed: $a"; exit 1; fi

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"

echo "All azure-cli tests passed!"
