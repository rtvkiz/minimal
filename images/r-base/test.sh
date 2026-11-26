#!/bin/bash
# Smoke test for minimal-r-base (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing R version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 | head -1)
echo "$v" | grep -qE '^R version [0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected R --version: $v"; exit 1; }

echo "Testing Rscript evaluates code (stats + base)..."
out=$(docker run --rm --network none --entrypoint /usr/bin/Rscript "$IMAGE" -e 'x <- c(2,4,4,4,5,5,7,9); cat(mean(x), sd(x) > 2, nchar("r-ok"), "\n")')
[ "$out" = "5 TRUE 4 " ] || { echo "FAIL: Rscript output: '$out'"; exit 1; }

echo "Testing R CMD SHLIB builds a C extension offline (the toolchain install.packages needs)..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
printf '#include <R.h>\nvoid add1(double *x){ *x += 1; }\n' > "$work/add1.c"; chmod 0644 "$work/add1.c"
docker run --rm --network none -v "$work:/work" -w /work "$IMAGE" CMD SHLIB add1.c >/dev/null 2>&1 \
  || { echo "FAIL: R CMD SHLIB failed"; exit 1; }
out=$(docker run --rm --network none -v "$work:/work" -w /work --entrypoint /usr/bin/Rscript "$IMAGE" -e 'dyn.load("add1.so"); cat(.C("add1", x=41)$x, "\n")')
[ "$out" = "42 " ] || { echo "FAIL: compiled extension output: '$out'"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying busybox sh only (declared: /usr/bin/R is a sh script), no bash, no apk..."
for f in /bin/bash /usr/bin/bash /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "busybox sh only (as expected)"

echo "All r-base tests passed!"
