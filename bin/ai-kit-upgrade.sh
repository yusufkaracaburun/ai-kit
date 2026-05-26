#!/usr/bin/env bash
# Refresh a project's .ai-kit-setup marker to the current ai-kit VERSION,
# preserving every existing branch choice. Use after upgrading ai-kit.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
VERSION="$(resolve_ai_kit_version "$AIKIT")"

usage() {
  echo "Usage: $0 /path/to/project"
  echo ""
  echo "Re-stamps .ai-kit-setup with the current ai-kit VERSION."
  echo "All existing branch choices are preserved verbatim."
  echo "Fails if no marker exists — run /ai:setup first."
  exit 1
}

if [ $# -ne 1 ]; then usage; fi
case "$1" in -h|--help) usage ;; esac

TARGET="$(cd "$1" && pwd)"
MARKER="$TARGET/.ai-kit-setup"

if [ ! -f "$MARKER" ]; then
  echo "No .ai-kit-setup at $TARGET" >&2
  echo "Run $AIKIT/bin/bootstrap-project.sh + /ai:setup first." >&2
  exit 2
fi

COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CHANGELOG="$AIKIT/CHANGELOG.md"

python3 - "$MARKER" "$VERSION" "$COMPLETED_AT" "$CHANGELOG" <<'PY'
import json, re, sys
from pathlib import Path

path, version, completed, changelog_path = sys.argv[1:5]

with open(path) as f:
    data = json.load(f)

old_version = data.get("ai_kit_version", "unknown")
data["ai_kit_version"] = version
data["completed_at"] = completed

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Upgraded marker {old_version} -> {version}")

if old_version == version or old_version == "unknown":
    sys.exit(0)

p = Path(changelog_path)
if not p.is_file():
    sys.exit(0)

# CHANGELOG is reverse-chronological: slice from the heading matching
# `version` down to (but not including) the heading matching `old_version`.
text = p.read_text()
heading_re = re.compile(r"^## ([0-9]+\.[0-9]+\.[0-9]+)(?:\s|$)", re.MULTILINE)
matches = list(heading_re.finditer(text))
if not matches:
    sys.exit(0)

start = None
end = len(text)
for m in matches:
    ver = m.group(1)
    if start is None and ver == version:
        start = m.start()
    elif start is not None and ver == old_version:
        end = m.start()
        break
if start is None:
    sys.exit(0)

snippet = text[start:end].rstrip()
if not snippet:
    sys.exit(0)

print()
print(f"Changes since v{old_version}:")
print("-" * 60)
print(snippet)
PY

echo ""
echo "Run: $AIKIT/bin/verify-setup.sh $TARGET --strict"
