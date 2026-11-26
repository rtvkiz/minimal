#!/bin/bash
# Smoke test for minimal-gcc (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing gcc, g++ and make versions..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 | head -1)
echo "$v" | grep -qE '^gcc .*[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected gcc --version: $v"; exit 1; }
docker run --rm --network none --entrypoint /usr/bin/g++ "$IMAGE" --version >/dev/null || { echo "FAIL: g++ missing"; exit 1; }
docker run --rm --network none --entrypoint /usr/bin/make "$IMAGE" --version >/dev/null || { echo "FAIL: make missing"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
printf '#include <stdio.h>\nint main(void){puts("c-ok");return 0;}\n' > "$work/hello.c"
printf '#include <iostream>\n#include <vector>\nint main(){std::vector<int> v{1,2,3};std::cout<<"cxx-ok "<<v.size()<<"\\n";}\n' > "$work/hello.cpp"
chmod 0644 "$work"/hello.*

echo "Testing an offline C compile + link + run..."
# Exercises cc1 -> as -> ld with crt1.o and the libc.so linker script: the part
# a toolchain image most often gets wrong.
docker run --rm --network none -v "$work:/work" "$IMAGE" -O2 -o /work/hello-c /work/hello.c \
  || { echo "FAIL: C compile failed"; exit 1; }
out=$(docker run --rm --network none -v "$work:/work" --entrypoint /work/hello-c "$IMAGE")
[ "$out" = "c-ok" ] || { echo "FAIL: C binary output: $out"; exit 1; }

echo "Testing an offline C++ compile + link + run (libstdc++)..."
docker run --rm --network none -v "$work:/work" --entrypoint /usr/bin/g++ "$IMAGE" -O2 -o /work/hello-cpp /work/hello.cpp \
  || { echo "FAIL: C++ compile failed"; exit 1; }
out=$(docker run --rm --network none -v "$work:/work" --entrypoint /work/hello-cpp "$IMAGE")
[ "$out" = "cxx-ok 3" ] || { echo "FAIL: C++ binary output: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell and no package manager..."
for f in /bin/sh /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "None present (as expected)"

echo "All gcc tests passed!"
