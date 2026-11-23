#!/bin/bash
# Smoke test for minimal-percona-xtradb-cluster-operator (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work" 2>/dev/null || docker run --rm -v "$work:/w" --entrypoint /bin/rm "$IMAGE" -rf /w/mysql /w/percona /w/proxysql 2>/dev/null; rm -rf "$work" 2>/dev/null || true' EXIT

echo "Testing --help (operator flags load)..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
echo "$h" | grep -q 'kubeconfig' || { echo "FAIL: unexpected --help: $h"; exit 1; }

echo "Testing the operator fails cleanly without a cluster..."
out=$(timeout 60 docker run --rm --network none "$IMAGE" 2>&1 || true)
# It probes the API server version first thing, so it must stop right there.
echo "$out" | grep -q 'unable to define server version' || { echo "FAIL: operator did not reach startup:"; echo "$out" | tail -8; exit 1; }
echo "$out" | grep -qE 'in-cluster configuration|no configuration has been provided|KUBERNETES_SERVICE_HOST' \
  || { echo "FAIL: did not stop at the kube client:"; echo "$out" | tail -8; exit 1; }

# The operator runs these init scripts FROM THIS IMAGE inside the PXC,
# HAProxy, ProxySQL and backup pods. Run each one the way those pods do - as
# the data-plane uid against a mounted volume - and check what lands there.
echo "Testing pxc-init-entrypoint.sh installs the PXC helpers (as uid 1001)..."
mkdir -p "$work/mysql" "$work/percona" "$work/proxysql"; chmod 0777 "$work"/*
docker run --rm --network none --user 1001:1001 -v "$work/mysql:/var/lib/mysql" \
  --entrypoint /pxc-init-entrypoint.sh "$IMAGE" >/dev/null 2>&1 \
  || { echo "FAIL: pxc-init-entrypoint.sh"; docker run --rm --user 1001:1001 -v "$work/mysql:/var/lib/mysql" --entrypoint /pxc-init-entrypoint.sh "$IMAGE" 2>&1 | tail -5; exit 1; }
for f in pxc-entrypoint.sh pxc-configure-pxc.sh liveness-check.sh readiness-check.sh peer-list xtrabackup-server-sidecar get-pxc-state mysql-state-monitor wsrep_cmd_notify_handler.sh; do
  [ -s "$work/mysql/$f" ] || { echo "FAIL: pxc init did not install $f"; ls -la "$work/mysql"; exit 1; }
done

echo "Testing haproxy-init-entrypoint.sh installs the HAProxy helpers..."
docker run --rm --network none --user 1001:1001 -v "$work/percona:/opt/percona" \
  --entrypoint /haproxy-init-entrypoint.sh "$IMAGE" >/dev/null 2>&1 || { echo "FAIL: haproxy-init-entrypoint.sh"; exit 1; }
for f in haproxy-entrypoint.sh haproxy_check_pxc.sh haproxy.cfg haproxy-global.cfg peer-list; do
  [ -s "$work/percona/$f" ] || { echo "FAIL: haproxy init did not install $f"; exit 1; }
done

echo "Testing the installed peer-list helper actually runs..."
out=$(docker run --rm --network none --entrypoint /peer-list "$IMAGE" -h 2>&1 || true)
echo "$out" | grep -qiE 'usage|-on-start|-service' || { echo "FAIL: peer-list: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

# Declared exception: bash + busybox are required by the init scripts above.
echo "Verifying restraint: no package manager..."
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found - restraint guard violated"; exit 1; } || true
echo "bash + busybox only (as declared)"

echo "All percona-xtradb-cluster-operator tests passed!"
