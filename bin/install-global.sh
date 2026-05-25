#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

write_ai_kit_root_config "$AIKIT"

# Symlink every subdirectory of $src_root into $target, refusing to clobber
# user/custom entries. Used for skills, agents — anything where each entry
# is a directory containing a manifest file (SKILL.md, AGENT.md).
install_dir_to() {
  local src_root="$1"
  local target="$2"
  local src_real
  if [ ! -d "$src_root" ]; then
    return 0
  fi
  src_real="$(cd "$src_root" && pwd -P)"
  mkdir -p "$target"
  for entry in "$src_root"/*/; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    dest="$target/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        resolved="$(cd "$dest" 2>/dev/null && pwd -P)" || resolved=""
        case "$resolved" in
          "$src_real"/*) rm -f "$dest" ;;
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
    ln -sf "$entry" "$dest"
    echo "Linked $name -> $dest"
  done
}

# Symlink every *.md file (top-level, not recursive) from $src_root into $target.
# Used for slash commands — each command is a single file, not a directory.
install_files_to() {
  local src_root="$1"
  local target="$2"
  local src_real
  if [ ! -d "$src_root" ]; then
    return 0
  fi
  src_real="$(cd "$src_root" && pwd -P)"
  mkdir -p "$target"
  for entry in "$src_root"/*.md; do
    [ -f "$entry" ] || continue
    name="$(basename "$entry")"
    dest="$target/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        resolved="$(cd "$(dirname "$dest")" 2>/dev/null && readlink "$dest")" || resolved=""
        case "$resolved" in
          "$src_real"/*|"$entry") rm -f "$dest" ;;
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
    ln -sf "$entry" "$dest"
    echo "Linked $name -> $dest"
  done
}

echo "Installing ai-kit globally..."
echo ""

PREFER_PLUGIN_MARKER="${HOME}/.config/ai-kit/prefer-plugin"
PREFER_PLUGIN=false
if [ -f "$PREFER_PLUGIN_MARKER" ]; then
  PREFER_PLUGIN=true
fi

if [ "$PREFER_PLUGIN" = true ]; then
  echo "=== Claude Code skills — skipped (prefer-plugin marker) ==="
  echo "  Install via /plugin install ai@yusufkaracaburun to get /ai:* skills."
else
  echo "=== Claude Code skills (~/.claude/skills) ==="
  install_dir_to "$PRIMITIVES/skills" "${HOME}/.claude/skills"
fi

echo ""
echo "=== Claude Code legacy (~/.agents/skills) ==="
install_dir_to "$PRIMITIVES/skills" "${HOME}/.agents/skills"

echo ""
echo "=== Cursor skills (~/.cursor/skills) ==="
install_dir_to "$PRIMITIVES/skills" "${HOME}/.cursor/skills"

echo ""
if [ "$PREFER_PLUGIN" = true ]; then
  echo "=== Claude Code subagents — skipped (prefer-plugin marker) ==="
  echo "  Install via /plugin install ai@yusufkaracaburun to get explore/reviewer/qa-runner."
else
  echo "=== Claude Code subagents (~/.claude/agents) ==="
  install_dir_to "$PRIMITIVES/agents" "${HOME}/.claude/agents"
fi

echo ""
if [ "$PREFER_PLUGIN" = true ]; then
  echo "=== Claude Code slash commands — skipped (prefer-plugin marker) ==="
  echo "  Install via /plugin install ai@yusufkaracaburun to get /ai:doctor etc."
else
  echo "=== Claude Code slash commands (~/.claude/commands) ==="
  install_files_to "$PRIMITIVES/commands" "${HOME}/.claude/commands"
fi

echo ""
echo "=== Cursor slash commands (~/.cursor/commands) ==="
install_files_to "$PRIMITIVES/commands" "${HOME}/.cursor/commands"

echo ""
echo "Saved ai-kit root to ~/.config/ai-kit/root"
echo "  AI_KIT_ROOT=$AIKIT"
echo ""
echo "Done. Run /ai:setup in any project to configure."
