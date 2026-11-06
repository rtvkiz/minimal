#!/bin/bash
# Smoke test for minimal-openldap (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing slapd version..."
ver=$(docker run --rm --entrypoint /usr/bin/slapd "$IMAGE" -VV 2>&1 || true)
echo "$ver" | head -1
echo "$ver" | grep -qE 'OpenLDAP: slapd 2\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected version output: $ver"; exit 1; }

echo "Testing the default refuses to start (fail-closed)..."
# REGRESSION GUARD: the package ships a sample slapd.conf with `rootpw secret`.
# The default cmd points slapd at an empty slapd.d so it can never come up on
# that config. If this starts serving, the image would ship a known password.
rc=0; docker run --rm "$IMAGE" >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL: slapd started with no user configuration"; exit 1; }
echo "slapd exited $rc without a user config (as expected)"

work=$(mktemp -d); chmod 0755 "$work"
cid=""
trap '[ -n "$cid" ] && docker rm -f "$cid" >/dev/null 2>&1; rm -rf "$work"' EXIT

HASH=$(docker run --rm --entrypoint /usr/bin/slappasswd "$IMAGE" -s smoke-pass)
case "$HASH" in "{SSHA}"*) ;; *) echo "FAIL: slappasswd returned '$HASH'"; exit 1 ;; esac

cat > "$work/slapd.conf" <<EOF
include  /etc/openldap/schema/core.schema
include  /etc/openldap/schema/cosine.schema
include  /etc/openldap/schema/inetorgperson.schema
pidfile  /var/lib/openldap/run/slapd.pid
modulepath /usr/lib/openldap
moduleload back_mdb.so
moduleload memberof.so
moduleload argon2.so
database mdb
suffix   "dc=example,dc=org"
rootdn   "cn=admin,dc=example,dc=org"
rootpw   $HASH
directory /var/lib/openldap/openldap-data
overlay memberof
EOF
printf 'dn: dc=example,dc=org\nobjectClass: dcObject\nobjectClass: organization\no: Example\ndc: example\n\ndn: cn=alice,dc=example,dc=org\nobjectClass: inetOrgPerson\ncn: alice\nsn: Smith\n' > "$work/base.ldif"
chmod 0644 "$work/slapd.conf" "$work/base.ldif"

echo "Testing slapd serves with a user config (mdb + overlay + argon2 modules)..."
cid=$(docker run -d -v "$work:/conf:ro" "$IMAGE" \
  -d stats -h ldap://0.0.0.0:1389/ -f /conf/slapd.conf)
ok=0
for _ in $(seq 1 30); do
  if docker exec "$cid" ldapwhoami -x -H ldap://127.0.0.1:1389 >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: slapd did not come up"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Testing ldapadd + ldapsearch round-trip..."
docker exec "$cid" ldapadd -x -H ldap://127.0.0.1:1389 \
  -D cn=admin,dc=example,dc=org -w smoke-pass -f /conf/base.ldif >/dev/null
out=$(docker exec "$cid" ldapsearch -x -LLL -H ldap://127.0.0.1:1389 \
  -b dc=example,dc=org "(cn=alice)" sn 2>&1)
echo "$out" | grep -q '^sn: Smith' || { echo "FAIL: search did not return the entry: $out"; exit 1; }
echo "✓ entry written and read back"

echo "Testing a wrong password is rejected..."
bad=$(docker exec "$cid" ldapwhoami -x -H ldap://127.0.0.1:1389 \
  -D cn=admin,dc=example,dc=org -w wrong-pass 2>&1 || true)
echo "$bad" | grep -q 'Invalid credentials (49)' || { echo "FAIL: bad bind not rejected: $bad"; exit 1; }
echo "✓ bad bind rejected"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All openldap tests passed!"
