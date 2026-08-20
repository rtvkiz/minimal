#!/usr/bin/env bash
#
# Assert that no melange build environment depends on a BARE toolchain provider.
#
# Wolfi ships language toolchains as versioned packages (go-1.26, nodejs-24,
# rust-1.90) plus an unversioned virtual provider (`go`, `nodejs`, `rust`) that
# every versioned package "provides". apk resolves a bare provider to the
# HIGHEST version available, so a recipe listing `- go` silently changes
# compiler the moment Wolfi publishes a new minor — no PR, no review, no signal.
#
# That is not hypothetical: on 2026-08-19 Wolfi published go-1.27 and all 58
# images on bare `go` jumped mid-build. trivy (the only image built with
# GOEXPERIMENT=jsonv2) broke on an encoding/json/v2 API change and four
# consecutive scheduled runs went red before anyone could look.
#
# Pinning matches upstream practice — every Go package in wolfi-dev/os pins the
# minor line explicitly. The pins are NOT a manual chore: update-wolfi-packages
# bumps them automatically and holds back only images whose build fails, so a
# pin is the last known-good probe result rather than a decision anyone has to
# remember.
#
# Same entrypoint locally (`make check-toolchain-pins`) and in CI, so they
# cannot drift.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Bare providers that must never appear in a build environment, and the
# versioned form each one must use instead. Add a row when a new language
# toolchain is onboarded.
BARE_PROVIDERS=(go nodejs rust)

fail=0
checked=0
err() { echo "  ✗ $*" >&2; fail=1; }

echo "Checking toolchain pins in melange build environments…"

shopt -s nullglob
for melange in images/*/melange.yaml; do
  image="${melange#images/}"; image="${image%/melange.yaml}"
  checked=$((checked + 1))
  for prov in "${BARE_PROVIDERS[@]}"; do
    # Match a package list entry that is EXACTLY the bare provider. Anchored so
    # go-1.26 / nodejs-24 / rust-1.90 (and unrelated names like `gomplate`) do
    # not match.
    if grep -qE "^[[:space:]]*-[[:space:]]+${prov}[[:space:]]*$" "$melange"; then
      err "$image: build environment uses bare '$prov' — pin the versioned package (e.g. ${prov}-<major.minor>)"
    fi
  done
done
shopt -u nullglob

if [ "$fail" -ne 0 ]; then
  echo
  echo "✗ toolchain pins FAILED — a bare provider lets apk pick the newest"
  echo "  toolchain silently, so an upstream release can change the compiler"
  echo "  mid-build. Pin the versioned package; update-wolfi-packages will"
  echo "  advance it automatically once the build is proven green."
  exit 1
fi
echo "✓ toolchain pins: ${checked} melange build environments, no bare providers"
