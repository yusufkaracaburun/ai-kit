#!/usr/bin/env bash
# Refresh a project's .ai-kit-setup marker to the current ai-kit VERSION,
# preserving every existing branch choice. Use after upgrading ai-kit.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
# shellcheck source=lib/link-primitives.sh
source "$SCRIPT_BIN/lib/link-primitives.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
VERSION="$(resolve_ai_kit_version "$AIKIT")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"
case "$AIKIT" in
  */plugins/cache/*)
    PRIMITIVES="$(resolve_primitives_root "${HOME}/.config/ai-kit/plugin-current")"
    ;;
esac

usage() {
  echo "Usage: $0 /path/to/project [--skip-skill-merge=true|false]"
  echo ""
  echo "Re-stamps .ai-kit-setup with the current ai-kit VERSION."
  echo "All existing branch choices are preserved verbatim."
  echo "Fails if no marker exists — run /ai:setup first."
  echo ""
  echo "--skip-skill-merge=true persists an opt-out (for projects where the"
  echo "ai-kit plugin already serves skills at user scope, and the project's"
  echo "own skills dirs should hold only hand-added custom skills) so future"
  echo "upgrades stop re-adding ai-kit's own skills there. Sticky once set;"
  echo "pass =false to undo. Not retroactive: an upgrade run before this flag"
  echo "was set still merged ai-kit's skills in that once — remove them by"
  echo "hand (or re-run merge_skills manually) if you don't want them there."
  exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then usage; fi
case "$1" in -h|--help) usage ;; esac

TARGET="$(cd "$1" && pwd)"
MARKER="$TARGET/.ai-kit-setup"
SKIP_SKILL_MERGE_ARG=""
if [ $# -eq 2 ]; then
  case "$2" in
    --skip-skill-merge=*) SKIP_SKILL_MERGE_ARG="${2#*=}" ;;
    *) usage ;;
  esac
fi

if [ ! -f "$MARKER" ]; then
  echo "No .ai-kit-setup at $TARGET" >&2
  echo "Run $AIKIT/bin/bootstrap-project.sh + /ai:setup first." >&2
  exit 2
fi

if [ -n "$SKIP_SKILL_MERGE_ARG" ]; then
  "$SCRIPT_BIN/write-setup-marker.sh" "$TARGET" "--skip-skill-merge=$SKIP_SKILL_MERGE_ARG"
fi
SKIP_SKILL_MERGE="$(python3 -c "import json; print(json.load(open('$MARKER')).get('branches',{}).get('skip_skill_merge', False))" 2>/dev/null || echo False)"

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

# Repair project skill/agent/command links against the new version. A
# project bootstrapped before the plugin-current indirection (#114 slice A)
# has links pinned straight into the OLD version's cache path — the marker
# now says $VERSION while the links still say $old_version, so the marker
# lies about install state until the old cache dir is GC'd and everything
# bricks. Only repairs a link kind the project actually has; --no-skills /
# --no-agents / --no-commands projects are left exactly as they are.
repair_links() {
  local dest_parent="$1" label="$2" kind="$3"
  local dir="$dest_parent/$kind"
  # -e follows a symlink and fails on a dead target — exactly the case being
  # repaired (a legacy link-all symlink into a GC'd version) — so a bare -e
  # guard would skip repairing it. -L catches the link regardless.
  [ -e "$dir" ] || [ -L "$dir" ] || return 0
  case "$kind" in
    skills)
      if [ -L "$dir" ]; then
        link_skills_all "$dest_parent" "$label" "$PRIMITIVES"
      elif [ "$SKIP_SKILL_MERGE" = "True" ]; then
        echo "Skipping ai-kit skill merge into $label (skip_skill_merge=true)"
      else
        merge_skills "$dest_parent" "$label" "$PRIMITIVES"
      fi
      ;;
    agents) merge_agents "$dest_parent" "$label" "$PRIMITIVES" ;;
    commands) merge_commands "$dest_parent" "$label" "$PRIMITIVES" ;;
  esac
}

echo ""
echo "Repairing project links against v${VERSION}…"
repair_links "$TARGET/.claude" ".claude/skills" skills
repair_links "$TARGET/.agents" ".agents/skills" skills
repair_links "$TARGET/.cursor" ".cursor/skills" skills
repair_links "$TARGET/.claude" ".claude/agents" agents
repair_links "$TARGET/.claude" ".claude/commands" commands
repair_links "$TARGET/.cursor" ".cursor/commands" commands

echo ""
echo "Run: $AIKIT/bin/verify-setup.sh $TARGET --strict"
