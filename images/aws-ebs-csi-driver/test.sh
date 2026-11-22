#!/bin/bash
# Smoke test for minimal-aws-ebs-csi-driver (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

name="ebs-test-$$"
work=$(mktemp -d); chmod 0777 "$work"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

echo "Testing driver version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 || true)
echo "$v" | grep -qE '"driverVersion": "v[0-9]+\.[0-9]+\.[0-9]+"' || { echo "FAIL: unexpected --version: $v"; exit 1; }

echo "Testing the controller starts and stays up without network (AWS_REGION given)..."
docker run -d --name "$name" --network none -e AWS_REGION=us-east-1 "$IMAGE" \
  controller --endpoint=unix:///tmp/csi.sock >/dev/null
for _ in $(seq 1 20); do docker logs "$name" 2>&1 | grep -q 'Driver Information' && break; sleep 0.5; done
docker logs "$name" 2>&1 | grep -q 'Driver="ebs.csi.aws.com"' || { echo "FAIL: driver did not initialise"; docker logs "$name" 2>&1 | tail -10; exit 1; }
sleep 3
[ "$(docker inspect -f '{{.State.Status}}' "$name")" = running ] || { echo "FAIL: controller exited"; docker logs "$name" 2>&1 | tail -10; exit 1; }

# The node plugin formats, checks, mounts and grows volumes by exec'ing these
# tools (k8s mount-utils). Run each one for real against sparse image files:
# no privileges or loop devices needed, and it proves the binaries and their
# shared libraries load - which a dependency bump would break.
echo "Testing the mount and filesystem tools the node plugin execs..."
truncate -s 64M "$work/ext.img"; truncate -s 320M "$work/xfs.img"; chmod 0666 "$work"/*.img
run() { e=$1; shift; docker run --rm --network none -v "$work:/w" --entrypoint "$e" "$IMAGE" "$@" 2>&1; }
run /usr/sbin/mkfs.ext4 -F -q /w/ext.img >/dev/null || { echo "FAIL: mkfs.ext4"; exit 1; }
run /usr/sbin/e2fsck -fn /w/ext.img >/dev/null || { echo "FAIL: e2fsck"; exit 1; }
run /usr/sbin/resize2fs /w/ext.img 32M | grep -q 'is now 32768' || { echo "FAIL: resize2fs"; exit 1; }
run /usr/sbin/mkfs.xfs -f -q /w/xfs.img >/dev/null || { echo "FAIL: mkfs.xfs"; exit 1; }
run /usr/sbin/xfs_repair -n /w/xfs.img >/dev/null || { echo "FAIL: xfs_repair"; exit 1; }
ids=$(run /usr/sbin/blkid /w/ext.img /w/xfs.img)
echo "$ids" | grep -q 'ext.img:.*TYPE="ext4"' || { echo "FAIL: blkid ext4: $ids"; exit 1; }
echo "$ids" | grep -q 'xfs.img:.*TYPE="xfs"' || { echo "FAIL: blkid xfs: $ids"; exit 1; }
for t in mount umount findmnt lsblk blockdev fsck; do
  run /usr/bin/$t --version >/dev/null || { echo "FAIL: $t missing or does not run"; exit 1; }
done
run /usr/bin/xfs_growfs -V | grep -q '^xfs_growfs version' || { echo "FAIL: xfs_growfs"; exit 1; }
run /usr/bin/nvme version | grep -q '^nvme version' || { echo "FAIL: nvme-cli"; exit 1; }

echo "Verifying non-root default (the node DaemonSet sets runAsUser: 0 itself)..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

# Declared exception: bash arrives as a runtime dependency of e2fsprogs-extra
# and xfsprogs-extra (resize2fs / xfs_growfs). Assert it is ONLY bash.
echo "Verifying restraint: no busybox /bin/sh and no package manager..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: /bin/sh found - restraint guard violated"; exit 1; } || true
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found - restraint guard violated"; exit 1; } || true
docker run --rm --entrypoint /bin/busybox "$IMAGE" true >/dev/null 2>&1 \
  && { echo "FAIL: busybox found - restraint guard violated"; exit 1; } || true
echo "Only bash (as declared)"

echo "All aws-ebs-csi-driver tests passed!"
