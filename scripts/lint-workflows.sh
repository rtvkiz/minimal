#!/usr/bin/env bash
#
# Lint every GitHub Actions workflow: schema/expressions (actionlint) plus the
# Bash embedded in each `run:` block (shellcheck, error-severity only).
#
# This is the guardrail for the class of bug that a workflow-only diff hides:
# a dropped `)` in a Bash associative array inside `run:` passes YAML validation
# and code review, then only detonates on the next *scheduled* run on main
# (workflows that don't trigger on pull_request never execute on the PR).
# actionlint feeds each run block to shellcheck, which flags the unparseable
# array (SC1072/SC1073) before merge.
#
# Severity is pinned to `error` so we catch syntax breaks without drowning in
# pre-existing style/info noise (SC2086 quoting, SC2129 redirect grouping).
#
# Same command runs locally (`make lint-workflows`) and in CI, so they can't drift.
set -euo pipefail

ACTIONLINT_VERSION="1.7.7"
SHELLCHECK_VERSION="0.10.0"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/minimal-workflow-lint"
mkdir -p "$cache"

# --- actionlint (pinned) ---
if command -v actionlint >/dev/null 2>&1 && [ "$(actionlint --version 2>/dev/null | head -1)" = "$ACTIONLINT_VERSION" ]; then
  actionlint_bin="$(command -v actionlint)"
elif [ -x "$cache/actionlint" ] && [ "$("$cache/actionlint" --version 2>/dev/null | head -1)" = "$ACTIONLINT_VERSION" ]; then
  actionlint_bin="$cache/actionlint"
else
  echo "→ fetching actionlint ${ACTIONLINT_VERSION}"
  curl -fsSL "https://raw.githubusercontent.com/rhysd/actionlint/v${ACTIONLINT_VERSION}/scripts/download-actionlint.bash" \
    | bash -s -- "$ACTIONLINT_VERSION" "$cache" >/dev/null
  actionlint_bin="$cache/actionlint"
fi

# --- shellcheck (actionlint shells out to it for `run:` blocks) ---
# Preinstalled on GitHub-hosted ubuntu runners; fetched locally if absent.
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck_bin="$(command -v shellcheck)"
elif [ -x "$cache/shellcheck" ]; then
  shellcheck_bin="$cache/shellcheck"
else
  echo "→ fetching shellcheck ${SHELLCHECK_VERSION}"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"; [ "$arch" = "arm64" ] && arch="aarch64"
  curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${os}.${arch}.tar.xz" \
    | tar -xJ -C "$cache" --strip-components=1 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"
  shellcheck_bin="$cache/shellcheck"
fi

# actionlint auto-discovers shellcheck on PATH and forwards SHELLCHECK_OPTS to it.
export PATH="$(dirname "$shellcheck_bin"):$PATH"
export SHELLCHECK_OPTS="--severity=error"

echo "actionlint $("$actionlint_bin" --version | head -1) + shellcheck $("$shellcheck_bin" --version | awk -F': ' '/^version/{print $2}')"
cd "$repo_root"
"$actionlint_bin" -color .github/workflows/*.yml
echo "✓ workflow lint clean"

# --- standalone shell scripts ---
# The workflows shell out to these (check-upstream.sh, apply-update.sh, the
# coverage gate, …); actionlint only sees run: blocks, so a syntax/quoting bug
# here would break update-versions / the gate the same way an unlinted run:
# block would. Lint them at the same error-severity bar (shebang picks dialect).
echo "shellchecking standalone scripts…"
mapfile -t script_files < <(ls .github/scripts/*.sh scripts/*.sh 2>/dev/null || true)
if [ "${#script_files[@]}" -gt 0 ]; then
  "$shellcheck_bin" --severity=error "${script_files[@]}"
fi
echo "✓ scripts lint clean"
