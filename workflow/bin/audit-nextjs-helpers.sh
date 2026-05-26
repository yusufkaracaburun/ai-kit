#!/usr/bin/env bash
# audit-architecture-nextjs helper-script.
#
# Sub-commands:
#   run_tools      <project-path>  -> one-line "Tools ingested: ..." header; caches raw output
#   detect_router  <project-path>  -> "app" | "pages" | "both" | "none"
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
  detect_router <project-path>
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
  local cache="${TMPDIR:-/tmp}/ai-kit-audit-nextjs-$ts"
  mkdir -p "$cache"

  local nextlint="✗"

  local next_bin
  if next_bin="$(resolve_bin next "$target")"; then
    if (cd "$target" && "$next_bin" lint --format=json 2>/dev/null) > "$cache/next-lint.json" \
        || [ -s "$cache/next-lint.json" ]; then
      nextlint="✓"
    fi
  fi

  echo "**Tools ingested:** next lint $nextlint"
  echo "Cache: $cache"
}

detect_router() {
  local target="$1"
  local app="no" pages="no"
  for candidate in app src/app; do
    if [ -d "$target/$candidate" ]; then
      app="yes"
      break
    fi
  done
  for candidate in pages src/pages; do
    if [ -d "$target/$candidate" ]; then
      pages="yes"
      break
    fi
  done
  if [ "$app" = "yes" ] && [ "$pages" = "yes" ]; then
    echo "both"
  elif [ "$app" = "yes" ]; then
    echo "app"
  elif [ "$pages" = "yes" ]; then
    echo "pages"
  else
    echo "none"
  fi
}

case "$SUB" in
  run_tools) run_tools "$TARGET" ;;
  detect_router) detect_router "$TARGET" ;;
  *) usage ;;
esac
