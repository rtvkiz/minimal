#!/bin/bash
# Smoke test for minimal-go-dev.
# Validates shell + openssh + auth stack on top of go prod (which already
# ships the toolchain). Most prod assertions are covered by go/test.sh.
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing Go version (parity with prod)..."
docker run --rm "$IMAGE" version | grep -qE "^go version go1\.2[6-9]"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing toolchain (gcc, make — needed for cgo)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gcc --version && make --version" >/dev/null

echo "Testing git (prod parity)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing openssh-client (private module fetch via SSH)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ssh -V" 2>&1 | grep -qE "OpenSSH_"

echo "Testing Go build works (cgo path)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
cd /tmp && mkdir -p hello && cd hello &&
cat > main.go <<EOF
package main
/*
static int add(int a, int b) { return a + b; }
*/
import "C"
import "fmt"
func main() { fmt.Println("3+4 =", C.add(3, 4)) }
EOF
go mod init hello >/dev/null 2>&1 &&
CGO_ENABLED=1 go build -o /tmp/hello-bin ./... &&
/tmp/hello-bin
' | grep -q "3+4 = 7"

echo "✓ All go-dev smoke tests passed"
