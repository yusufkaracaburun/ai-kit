#!/usr/bin/env bash
# audit-architecture-typescript helper-script.
#
# Sub-commands:
#   run_tools <project-path>  -> one-line "Tools ingested: ... (force-strict=yes)" header; caches raw output
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
  local cache="${TMPDIR:-/tmp}/ai-kit-audit-typescript-$ts"
  mkdir -p "$cache"

  local tsc="✗"
  local ts_prune="✗"
  local eslint="✗"

  local tsc_bin
  if tsc_bin="$(resolve_bin tsc "$target")"; then
    # force-strict on the audit run regardless of project tsconfig.
    if (cd "$target" && "$tsc_bin" --noEmit --strict --pretty false 2>&1) > "$cache/tsc-strict.log" \
        || [ -s "$cache/tsc-strict.log" ]; then
      tsc="✓"
    fi
  fi

  local prune_bin
  if prune_bin="$(resolve_bin ts-prune "$target")"; then
    if (cd "$target" && "$prune_bin" --json 2>/dev/null) > "$cache/ts-prune.json" \
        || [ -s "$cache/ts-prune.json" ]; then
      ts_prune="✓"
    fi
  fi

  local eslint_bin
  if eslint_bin="$(resolve_bin eslint "$target")"; then
    if (cd "$target" && "$eslint_bin" --format json . 2>/dev/null) > "$cache/eslint-ts.json" \
        || [ -s "$cache/eslint-ts.json" ]; then
      eslint="✓"
    fi
  fi

  echo "**Tools ingested:** tsc $tsc · ts-prune $ts_prune · ESLint $eslint · force-strict=yes"
  echo "Cache: $cache"
}

case "$SUB" in
  run_tools) run_tools "$TARGET" ;;
  *) usage ;;
esac
