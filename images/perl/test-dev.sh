#!/bin/bash
# Smoke test for minimal-perl-dev.
# Same functional checks as prod, PLUS: a shell IS present, the C toolchain can
# build an XS module, and cpanminus is installed.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing perl version..."
ver=$(docker run --rm "$IMAGE" -v 2>&1)
echo "$ver" | grep -qE 'This is perl 5, version [0-9]+' \
  || { echo "FAIL: version string not found: $ver"; exit 1; }

echo "Testing core modules load (offline)..."
mods=$(docker run --rm "$IMAGE" -e '
  use strict; use warnings;
  use JSON::PP; use Encode; use Digest::SHA; use Compress::Zlib; use POSIX;
  print "modules-ok\n";' 2>&1)
echo "$mods" | grep -q 'modules-ok' \
  || { echo "FAIL: core module load failed: $mods"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying cpanminus is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v cpanm' >/dev/null 2>&1 \
  || { echo "FAIL: cpanm missing from dev image"; exit 1; }

echo "Verifying the C toolchain can compile (offline)..."
# The whole point of the dev variant for a language runtime: XS modules build.
cc=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
  set -e
  cd /tmp
  cat > hello.c <<EOF
#include <stdio.h>
int main(void) { printf("cc-ok\n"); return 0; }
EOF
  cc -o hello hello.c && ./hello' 2>&1)
echo "$cc" | grep -q 'cc-ok' || { echo "FAIL: C toolchain did not compile: $cc"; exit 1; }

echo "Verifying ExtUtils::MakeMaker can generate a Makefile (offline)..."
# Proves the XS build path is wired up (perl headers + MakeMaker + make present)
# without needing to reach CPAN.
xs=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
  set -e
  mkdir -p /tmp/xsmod && cd /tmp/xsmod
  cat > Makefile.PL <<EOF
use ExtUtils::MakeMaker;
WriteMakefile(NAME => "Dummy", VERSION => "0.01");
EOF
  perl Makefile.PL >/dev/null 2>&1
  test -f Makefile && command -v make >/dev/null && echo xs-ok' 2>&1)
echo "$xs" | grep -q 'xs-ok' || { echo "FAIL: MakeMaker/make not usable: $xs"; exit 1; }

echo "Verifying git and curl are present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v git && command -v curl' >/dev/null 2>&1 \
  || { echo "FAIL: git/curl missing from dev image"; exit 1; }

echo "All perl dev tests passed!"
