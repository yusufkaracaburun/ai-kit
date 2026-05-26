#!/usr/bin/env bash
# audit-architecture-react helper-script.
#
# Sub-commands:
#   run_tools   <project-path>  -> one-line "Tools ingested: ..." header; caches raw output
#   detect_rsc  <project-path>  -> "yes" | "no"
#
# Tool-gate protocol: every external tool is wrapped (`command -v` or
# `./node_modules/.bin/*`) and degrades to ✗ when absent. Tool absence is
# never fatal. See standards/contracts/audit-architecture-extension.contract.md.

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <subcommand> <project-path>

Subcommands:
  run_tools <project-path>
  detect_rsc <project-path>
EOF
  exit 2
}

if [ $# -lt 2 ]; then usage; fi

SUB="$1"
TARGET="$(cd "$2" && pwd)"

resolve_bin() {
  local tool="$1" target="$2"
  if [ -x "$target/node_modules/.bin/$tool" ]; then
    echo "$target/node_modules/.bin/$tool"
    return 0
  fi
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi
  return 1
}

run_tools() {
  local target="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local cache="${TMPDIR:-/tmp}/ai-kit-audit-react-$ts"
  mkdir -p "$cache"

  local eslint="✗"
  local tsc="✗"

  local eslint_bin
  if eslint_bin="$(resolve_bin eslint "$target")"; then
    if (cd "$target" && "$eslint_bin" --format json . 2>/dev/null) > "$cache/eslint.json" \
        || [ -s "$cache/eslint.json" ]; then
      eslint="✓"
    fi
  fi

  if [ -f "$target/tsconfig.json" ]; then
    local tsc_bin
    if tsc_bin="$(resolve_bin tsc "$target")"; then
      if (cd "$target" && "$tsc_bin" --noEmit --pretty false 2>&1) > "$cache/tsc.log" \
          || [ -s "$cache/tsc.log" ]; then
        tsc="✓"
      fi
    fi
  fi

  echo "**Tools ingested:** ESLint $eslint · tsc $tsc"
  echo "Cache: $cache"
}

detect_rsc() {
  local target="$1"
  local rsc_root=""
  for candidate in app src/app; do
    if [ -d "$target/$candidate" ]; then
      rsc_root="$target/$candidate"
      break
    fi
  done
  if [ -z "$rsc_root" ]; then
    echo "no"
    return 0
  fi
  if grep -rlE "^['\"]use client['\"]" "$rsc_root" 2>/dev/null | grep -q .; then
    echo "yes"
  else
    echo "no"
  fi
}

case "$SUB" in
  run_tools) run_tools "$TARGET" ;;
  detect_rsc) detect_rsc "$TARGET" ;;
  *) usage ;;
esac
