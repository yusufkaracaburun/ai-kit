#!/usr/bin/env bash
# Print a one-screen status of a project's ai-kit install.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
# shellcheck source=lib/detect-lib.sh
source "$SCRIPT_BIN/lib/detect-lib.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
KIT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"

usage() {
  echo "Usage: $0 [path]   (default: current directory)"
  exit 1
}

case "${1:-}" in -h|--help) usage ;; esac

TARGET="${1:-$(pwd)}"
if [ ! -d "$TARGET" ]; then
  echo "Not a directory: $TARGET" >&2
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"
MARKER="$TARGET/.ai-kit-setup"

echo "ai-kit @ $AIKIT (v$KIT_VERSION)"
echo "project   $TARGET"
echo ""

if [ ! -f "$MARKER" ]; then
  echo "Marker:   absent"
  echo "          → run /aikit-setup (or $AIKIT/bin/bootstrap-project.sh $TARGET first)"
  echo ""
else
  marker_version="$(python3 -c "import json; print(json.load(open('$MARKER')).get('ai_kit_version','?'))")"
  marker_completed="$(python3 -c "import json; print(json.load(open('$MARKER')).get('completed_at','?'))")"
  echo "Marker:   $marker_version (stamped $marker_completed)"
  if [ "$marker_version" != "$KIT_VERSION" ]; then
    echo "          → drift vs ai-kit v$KIT_VERSION — run: ai-kit-upgrade.sh $TARGET"
  fi
  python3 - "$MARKER" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
br = data.get("branches", {})
order = [
    ("setup_mode", "setup-mode"),
    ("setup_tier", "tier"),
    ("docker", "docker"),
    ("issue_tracker", "tracker"),
    ("workflow", "workflow"),
    ("architecture", "architecture"),
    ("sandcastle", "sandcastle"),
    ("automation_recommender", "recommender"),
]
shown = []
def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return v
for key, label in order:
    if key in br:
        shown.append(f"{label}={fmt(br[key])}")
print("Branches: " + ", ".join(shown) if shown else "Branches: (none)")
deferred = [label for key, label in order if br.get(key) == "deferred"]
if deferred:
    print("Deferred: " + ", ".join(deferred))
PY
  echo ""
fi

detect_bootstrap_state "$TARGET"
echo "Bootstrap: $BOOTSTRAP_STATE"
if [ "${#BOOTSTRAP_MISSING[@]}" -gt 0 ]; then
  echo "           missing: $(IFS=', '; echo "${BOOTSTRAP_MISSING[*]}")"
fi
echo ""

for d in .claude/skills .agents/skills .cursor/skills; do
  if [ -d "$TARGET/$d" ]; then
    count="$(find "$TARGET/$d" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | wc -l | tr -d ' ')"
    echo "$d: $count skills"
  fi
done
echo ""

if [ -f "$MARKER" ]; then
  if "$AIKIT/bin/verify-setup.sh" "$TARGET" --strict >/dev/null 2>&1; then
    echo "Verify:   strict pass"
  elif "$AIKIT/bin/verify-setup.sh" "$TARGET" --strict --minimal >/dev/null 2>&1; then
    echo "Verify:   minimal (Tier A) pass — Tier B has gaps"
  else
    echo "Verify:   FAIL — run: $AIKIT/bin/verify-setup.sh $TARGET --strict"
  fi
fi
