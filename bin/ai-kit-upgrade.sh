#!/usr/bin/env bash
# Refresh a project's .ai-kit-setup marker to the current ai-kit VERSION,
# preserving every existing branch choice. Use after upgrading ai-kit.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"

usage() {
  echo "Usage: $0 /path/to/project"
  echo ""
  echo "Re-stamps .ai-kit-setup with the current ai-kit VERSION."
  echo "All existing branch choices are preserved verbatim."
  echo "Fails if no marker exists — run /aikit-setup first."
  exit 1
}

if [ $# -ne 1 ]; then usage; fi
case "$1" in -h|--help) usage ;; esac

TARGET="$(cd "$1" && pwd)"
MARKER="$TARGET/.ai-kit-setup"

if [ ! -f "$MARKER" ]; then
  echo "No .ai-kit-setup at $TARGET" >&2
  echo "Run $AIKIT/bin/bootstrap-project.sh + /aikit-setup first." >&2
  exit 2
fi

COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

python3 - "$MARKER" "$VERSION" "$COMPLETED_AT" <<'PY'
import json, sys

path, version, completed = sys.argv[1:4]

with open(path) as f:
    data = json.load(f)

old_version = data.get("ai_kit_version", "unknown")
data["ai_kit_version"] = version
data["completed_at"] = completed

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Upgraded marker {old_version} -> {version}")
PY

echo "Run: $AIKIT/bin/verify-setup.sh $TARGET --strict"
