#!/usr/bin/env bash
# Read or flip the project lifecycle phase in .ai-kit-setup.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<EOF
Usage: $0 [development|production] [--project PATH]

  No arg: print the current lifecycle phase (default: production).
  Arg:    write the new phase to .ai-kit-setup.

  --project PATH   Project root (default: \$PWD).
EOF
  exit 1
}

PHASE=""
PROJECT="$(pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    development|production) PHASE="$1"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    -h|--help) usage ;;
    *) echo "error: unknown arg '$1'" >&2; usage ;;
  esac
done

if [ ! -d "$PROJECT" ]; then
  echo "error: not a directory: $PROJECT" >&2
  exit 2
fi
PROJECT="$(cd "$PROJECT" && pwd)"
MARKER="$PROJECT/.ai-kit-setup"

if [ ! -f "$MARKER" ]; then
  echo "error: $MARKER missing — run /ai:setup first" >&2
  exit 2
fi

if [ -z "$PHASE" ]; then
  CURRENT="$(python3 -c "
import json, sys
d = json.load(open('$MARKER'))
print(d.get('branches', {}).get('lifecycle', 'production'))
")"
  echo "$CURRENT"
  exit 0
fi

python3 - "$MARKER" "$PHASE" <<'PY'
import json, sys
path, phase = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
branches = data.get("branches", {})
old = branches.get("lifecycle", "production")
branches["lifecycle"] = phase
data["branches"] = branches
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"lifecycle: {old} → {phase}")
print("Rule loads on next session — restart Claude Code to apply.")
PY
