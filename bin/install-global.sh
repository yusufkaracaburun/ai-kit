#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

write_ai_kit_root_config "$AIKIT"

install_to() {
  local target="$1"
  local aikit_real
  aikit_real="$(cd "$AIKIT/workflow/skills" && pwd -P)"
  mkdir -p "$target"
  for skill in "$AIKIT/workflow/skills"/*/; do
    name="$(basename "$skill")"
    dest="$target/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      # Re-link only if it already points into ai-kit; never clobber user/custom skills
      if [ -L "$dest" ]; then
        resolved="$(cd "$dest" 2>/dev/null && pwd -P)" || resolved=""
        case "$resolved" in
          "$aikit_real"/*) rm -f "$dest" ;;
          *)
            echo "Skipped $name (existing non-aikit entry at $dest)"
            continue
            ;;
        esac
      else
        echo "Skipped $name (existing non-aikit entry at $dest)"
        continue
      fi
    fi
    ln -sf "$skill" "$dest"
    echo "Linked $name -> $dest"
  done
}

echo "Installing ai-kit skills globally..."
echo ""

echo "=== Claude Code (~/.claude/skills) ==="
install_to "${HOME}/.claude/skills"

echo ""
echo "=== Claude Code legacy (~/.agents/skills) ==="
install_to "${HOME}/.agents/skills"

echo ""
echo "=== Cursor (~/.cursor/skills) ==="
install_to "${HOME}/.cursor/skills"

echo ""
echo "Saved ai-kit root to ~/.config/ai-kit/root"
echo "  AI_KIT_ROOT=$AIKIT"
echo ""
echo "Done. Run /setup in any project to configure."
