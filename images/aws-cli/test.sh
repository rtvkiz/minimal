#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone (grep closes
# the pipe early, docker exits 141, pipefail blows the script). Capture to
# a variable then grep.
set -eu
: "${IMAGE:?IMAGE env var required}"

# Dummy credentials: every check below is offline, nothing is ever sent.
FAKE_CREDS=(-e AWS_ACCESS_KEY_ID=testing -e AWS_SECRET_ACCESS_KEY=testing -e AWS_DEFAULT_REGION=us-east-1)

echo "Testing aws --version..."
VERSION_OUT=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$VERSION_OUT"
echo "$VERSION_OUT" | grep -qE '^aws-cli/2\.[0-9]+\.[0-9]+ Python/3\.' \
  || { echo "FAIL: expected aws-cli/2.x.y on Python 3"; exit 1; }

echo "Testing SigV4 signing offline (s3 presign)..."
# presign computes a SigV4 signature locally — exercises botocore, the
# credential chain and the crypto stack without any network access.
URL=$(docker run --rm --network none "${FAKE_CREDS[@]}" "$IMAGE" \
  s3 presign s3://example-bucket/smoke.txt --expires-in 60 2>&1)
echo "$URL" | cut -c1-120
echo "$URL" | grep -q 'X-Amz-Signature=' || { echo "FAIL: presign produced no signature"; exit 1; }
echo "$URL" | grep -q 'X-Amz-Credential=testing' || { echo "FAIL: presign ignored the credential chain"; exit 1; }

echo "Testing service model loading (generate-cli-skeleton)..."
SKEL=$(docker run --rm --network none "${FAKE_CREDS[@]}" "$IMAGE" \
  ec2 run-instances --generate-cli-skeleton 2>&1)
echo "$SKEL" | grep -q '"ImageId"' || { echo "FAIL: ec2 model did not load"; echo "$SKEL" | head -5; exit 1; }

echo "Testing aws configure persists to ~/.aws..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work" 2>/dev/null || true' EXIT
docker run --rm --network none -v "$work:/home/nonroot/.aws" "$IMAGE" \
  configure set region eu-west-2
REGION=$(docker run --rm --network none -v "$work:/home/nonroot/.aws" "$IMAGE" \
  configure get region 2>&1)
[ "$REGION" = "eu-west-2" ] || { echo "FAIL: configure get returned '$REGION'"; exit 1; }
[ -s "$work/config" ] || { echo "FAIL: ~/.aws/config was not written"; exit 1; }
echo "configure set/get round-trip OK"

echo "Testing a clean credentials error with no network..."
ERR=$(docker run --rm --network none "$IMAGE" sts get-caller-identity 2>&1 || true)
echo "$ERR" | grep -q 'Unable to locate credentials' \
  || { echo "FAIL: unexpected error: $ERR"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All aws-cli tests passed!"
