#!/usr/bin/env bash
# audit-architecture-vue helper-script.
#
# Sub-commands:
#   run_tools   <project-path>  -> one-line "Tools ingested: ..." header; caches raw output
#   detect_api  <project-path>  -> "composition" | "options" | "mixed" | "none"
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
  detect_api <project-path>
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
  local cache="${TMPDIR:-/tmp}/ai-kit-audit-vue-$ts"
  mkdir -p "$cache"

  local eslint="✗" vuetsc="✗"

  local eslint_bin
  if eslint_bin="$(resolve_bin eslint "$target")"; then
    if (cd "$target" && "$eslint_bin" --format json . 2>/dev/null) > "$cache/eslint.json" \
        || [ -s "$cache/eslint.json" ]; then
      eslint="✓"
    fi
  fi

  if [ -f "$target/tsconfig.json" ]; then
    local vuetsc_bin
    if vuetsc_bin="$(resolve_bin vue-tsc "$target")"; then
      if (cd "$target" && "$vuetsc_bin" --noEmit 2>&1) > "$cache/vue-tsc.txt" \
          || [ -s "$cache/vue-tsc.txt" ]; then
        vuetsc="✓"
      fi
    fi
  fi

  echo "**Tools ingested:** ESLint $eslint · vue-tsc $vuetsc"
  echo "Cache: $cache"
}

# Counts SFCs by API style. `<script setup>` is Composition; a `<script>` block
# exporting an object literal is Options. An SFC using both counts as Options —
# the Options block is the one that carries the paradigm cost.
detect_api() {
  local target="$1"
  local composition=0 options=0 sfc

  while IFS= read -r sfc; do
    if grep -qE '^\s*export default \{' "$sfc" 2>/dev/null; then
      options=$((options + 1))
    elif grep -qE '<script[^>]*\bsetup\b' "$sfc" 2>/dev/null; then
      composition=$((composition + 1))
    fi
  done < <(find "$target" -name '*.vue' -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null)

  if [ "$composition" -eq 0 ] && [ "$options" -eq 0 ]; then
    echo "none"
  elif [ "$options" -eq 0 ]; then
    echo "composition"
  elif [ "$composition" -eq 0 ]; then
    echo "options"
  else
    echo "mixed"
  fi
}

case "$SUB" in
  run_tools) run_tools "$TARGET" ;;
  detect_api) detect_api "$TARGET" ;;
  *) usage ;;
esac
