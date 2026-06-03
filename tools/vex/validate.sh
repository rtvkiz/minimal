#!/usr/bin/env bash
# Validate every vex/<image>.openvex.json doc against the OpenVEX v0.2.0 shape
# we use in this repo. Hand-rolled checks (jq, no extra runtime deps).
#
# Exits non-zero on the first malformed file so CI fails loudly.
#
# Usage:
#   tools/vex/validate.sh                  # validate every vex/*.openvex.json
#   tools/vex/validate.sh vex/nginx.openvex.json [...]   # specific files

set -euo pipefail

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  shopt -s nullglob
  files=(vex/*.openvex.json)
  shopt -u nullglob
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "no VEX files to validate" >&2
  exit 1
fi

errors=0
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "FAIL $f: file not found" >&2
    errors=$((errors + 1))
    continue
  fi

  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "FAIL $f: invalid JSON" >&2
    errors=$((errors + 1))
    continue
  fi

  # Required top-level fields.
  for key in '@context' '@id' author timestamp version statements; do
    if ! jq -e --arg k "$key" 'has($k)' "$f" >/dev/null; then
      echo "FAIL $f: missing required field '$key'" >&2
      errors=$((errors + 1))
      continue 2
    fi
  done

  # @context must be an OpenVEX context URI.
  ctx=$(jq -r '."@context"' "$f")
  case "$ctx" in
    https://openvex.dev/ns/v0.2.0|https://openvex.dev/ns) ;;
    *) echo "FAIL $f: unexpected @context '$ctx'" >&2; errors=$((errors + 1)); continue ;;
  esac

  # version must be a positive integer.
  if ! jq -e '.version | type == "number" and . >= 1 and floor == .' "$f" >/dev/null; then
    echo "FAIL $f: 'version' must be a positive integer" >&2
    errors=$((errors + 1))
    continue
  fi

  # statements must be an array.
  if ! jq -e '.statements | type == "array"' "$f" >/dev/null; then
    echo "FAIL $f: 'statements' must be an array" >&2
    errors=$((errors + 1))
    continue
  fi

  # If any statements exist, each needs vulnerability.name, products[], status.
  stmt_count=$(jq '.statements | length' "$f")
  if [ "$stmt_count" -gt 0 ]; then
    bad=$(jq -r '
      [ .statements[]
        | select(
            (has("vulnerability") | not)
            or (.vulnerability | has("name") | not)
            or (has("products") | not)
            or (.products | type != "array")
            or (.products | length == 0)
            or (has("status") | not)
            or ((.status | IN("not_affected","affected","fixed","under_investigation")) | not)
            or (.status == "not_affected" and (has("justification") | not))
          )
        | .vulnerability.name // "<unknown>"
      ] | join(",")
    ' "$f")
    if [ -n "$bad" ]; then
      echo "FAIL $f: malformed statements for: $bad" >&2
      errors=$((errors + 1))
      continue
    fi
  fi

  echo "ok   $f ($stmt_count statement(s))"
done

if [ "$errors" -gt 0 ]; then
  echo "" >&2
  echo "$errors file(s) failed validation" >&2
  exit 1
fi

echo ""
echo "All ${#files[@]} VEX file(s) valid."
