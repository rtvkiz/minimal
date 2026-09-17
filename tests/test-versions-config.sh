#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/check-versions-config.sh"
updater="$repo_root/.github/scripts/apply-update.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/valid.yaml" <<'YAML'
- name: default-field
  tarball: {url: "https://example.invalid/{version}.tgz", field: sha256}
- name: custom-field
  tarballs:
    - {urls: ["https://example.invalid/{version}.tgz"], field: cli_sha256, algo: sha256}
YAML
"$validator" "$tmpdir/valid.yaml" >/dev/null

cat >"$tmpdir/custom-field-without-algo.yaml" <<'YAML'
- name: temporal-cli
  tarball: {url: "https://example.invalid/{version}.tgz", field: cli_sha256}
YAML
if "$validator" "$tmpdir/custom-field-without-algo.yaml" >"$tmpdir/output" 2>&1; then
  echo "expected a custom checksum field without algo to fail" >&2
  exit 1
fi
grep -Fq "unsupported digest algorithm \"cli_sha256\"" "$tmpdir/output"

cat >"$tmpdir/unsupported-algo.yaml" <<'YAML'
- name: weak-digest
  tarball: {url: "https://example.invalid/{version}.tgz", field: checksum, algo: md5}
YAML
if "$validator" "$tmpdir/unsupported-algo.yaml" >"$tmpdir/output" 2>&1; then
  echo "expected an unsupported digest algorithm to fail" >&2
  exit 1
fi
grep -Fq "set algo to sha256 or sha512" "$tmpdir/output"

# Exercise the same custom-field path end to end without network access.
printf 'temporal-cli-1.9.1 fixture\n' >"$tmpdir/upstream.tar.gz"
expected_digest="$(sha256sum "$tmpdir/upstream.tar.gz" | awk '{print $1}')"
cat >"$tmpdir/melange.yaml" <<'YAML'
vars:
  cli_version: 1.8.3
  cli_sha256: old
YAML
row="$(jq -nc \
  --arg path "$tmpdir/melange.yaml" \
  --arg url "file://$tmpdir/upstream.tar.gz" \
  '{name:"temporal-cli", files:[
      {path:$path, pattern:"^  cli_version: .*", template:"  cli_version: {version}"},
      {path:$path, pattern:"^  cli_sha256: .*", template:"  cli_sha256: {cli_sha256}"}
    ], tarball:{url:$url, field:"cli_sha256", algo:"sha256"}}')"
"$updater" "$row" 1.9.1 >/dev/null
grep -Fq '  cli_version: 1.9.1' "$tmpdir/melange.yaml"
grep -Fq "  cli_sha256: $expected_digest" "$tmpdir/melange.yaml"

# Runtime validation remains a second line of defence if lint is bypassed.
invalid_row="$(jq -nc \
  --arg path "$tmpdir/melange.yaml" \
  --arg url "file://$tmpdir/upstream.tar.gz" \
  '{name:"temporal-cli", files:[$path],
    tarball:{url:$url, field:"cli_sha256"}}')"
if "$updater" "$invalid_row" 1.9.1 >"$tmpdir/output" 2>&1; then
  echo "expected updater runtime validation to reject cli_sha256 as an algorithm" >&2
  exit 1
fi
grep -Fq "unsupported digest algorithm 'cli_sha256'" "$tmpdir/output"

echo "✓ versions config validator tests passed"
