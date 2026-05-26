#!/usr/bin/env bash
# audit-architecture-shadcn helper-script.
#
# Sub-commands:
#   run_tools     <project-path>  -> one-line "Tools ingested: ..." header
#   read_aliases  <project-path>  -> one `key=value` per line: ui=…, components=…, utils=…
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
  read_aliases <project-path>
EOF
  exit 2
}

if [ $# -lt 2 ]; then usage; fi

SUB="$1"
TARGET="$(cd "$2" && pwd)"

run_tools() {
  local target="$1"
  local cfg="$target/components.json"
  local status="✗"

  if [ -f "$cfg" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$cfg" >/dev/null 2>&1; then
    status="✓"
  fi

  echo "**Tools ingested:** components.json $status"
}

read_aliases() {
  local target="$1"
  local cfg="$target/components.json"

  if [ ! -f "$cfg" ]; then
    return 0
  fi

  python3 - "$cfg" <<'PY' || true
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    aliases = data.get("aliases", {}) or {}
    for k in ("ui", "components", "utils", "hooks", "lib"):
        if k in aliases:
            print(f"{k}={aliases[k]}")
except Exception:
    pass
PY
}

case "$SUB" in
  run_tools) run_tools "$TARGET" ;;
  read_aliases) read_aliases "$TARGET" ;;
  *) usage ;;
esac
