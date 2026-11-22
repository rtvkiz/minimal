#!/bin/bash
# Smoke test for minimal-aws-load-balancer-controller (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing --help (flags load) and the injected version..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
for f in --cluster-name --aws-region --aws-vpc-id --ingress-class; do
  echo "$h" | grep -q -- "$f" || { echo "FAIL: --help is missing $f"; exit 1; }
done
echo "$h" | grep -qE '"GitVersion":"v[0-9]+\.[0-9]+\.[0-9]+"' || { echo "FAIL: version not injected: $(echo "$h" | head -1)"; exit 1; }

echo "Testing the upstream entrypoint path..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = '["/controller"]' ] || { echo "FAIL: entrypoint is $ep, upstream's chart runs /controller"; exit 1; }

echo "Testing it needs EC2 metadata or --aws-region, and says so..."
out=$(timeout 60 docker run --rm --network none "$IMAGE" --cluster-name smoke 2>&1 || true)
echo "$out" | grep -q 'specify --aws-region instead' || { echo "FAIL: unexpected output without IMDS:"; echo "$out" | tail -5; exit 1; }

echo "Testing AWS client setup succeeds offline and stops at the Kubernetes client..."
# With region + VPC given there is no IMDS call: the AWS SDK clients build, then
# the controller must exit cleanly at the in-cluster REST config, not hang.
out=$(timeout 60 docker run --rm --network none "$IMAGE" \
  --cluster-name smoke --aws-region us-east-1 --aws-vpc-id vpc-0123456789abcdef0 2>&1 || true)
echo "$out" | grep -q 'unable to initialize AWS cloud' && { echo "FAIL: AWS client setup failed:"; echo "$out" | tail -5; exit 1; } || true
echo "$out" | grep -q 'unable to load in-cluster configuration' || { echo "FAIL: did not reach the kube client:"; echo "$out" | tail -5; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All aws-load-balancer-controller tests passed!"
