#!/bin/bash
# Smoke test for minimal-julia (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing julia version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^julia version 1\.[0-9]+' || { echo "FAIL: unexpected julia --version: $v"; exit 1; }

echo "Testing the precompiled stdlib (LinearAlgebra, Statistics, Dates)..."
out=$(docker run --rm --network none "$IMAGE" --startup-file=no -e 'using LinearAlgebra, Statistics, Dates; println(round(det([2.0 1; 1 3]); digits=3), " ", mean([1,2,3,6]), " ", Dates.year(Date(2026,11,27)))')
[ "$out" = "5.0 3.0 2026" ] || { echo "FAIL: stdlib output: '$out'"; exit 1; }

echo "Testing Pkg.generate + running the new package offline..."
vol="minimal-julia-smoke-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
docker run --rm --network none -v "$vol:/app" "$IMAGE" --startup-file=no -e 'using Pkg; Pkg.generate("Hello")' >/dev/null 2>&1 \
  || { echo "FAIL: Pkg.generate"; exit 1; }
# Loading it precompiles it into the depot under HOME. (Julia 1.13's template
# no longer defines greet(), so check the module loads rather than calling it.)
out=$(docker run --rm --network none -v "$vol:/app" "$IMAGE" --startup-file=no --project=/app/Hello -e 'using Hello; println("loaded ", nameof(Hello))' 2>&1)
echo "$out" | grep -qx 'loaded Hello' || { echo "FAIL: generated package did not load: '$out'"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell and no package manager..."
for f in /bin/sh /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "None present (as expected)"

echo "All julia tests passed!"
