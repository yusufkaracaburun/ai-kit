#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
# shellcheck source=lib/link-primitives.sh
source "$SCRIPT_BIN/lib/link-primitives.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

# The root the last install ran from. Links made then point into it, and a
# plugin root carries its version in the path
# (~/.claude/plugins/cache/.../ai/1.63.0), so after an upgrade those links
# are dead and have no /ai-kit/ segment for install_dir_to's sweep to recognise.
# Read it before write_ai_kit_root_config overwrites the file.
PREV_ROOT=""
if [ -f "${HOME}/.config/ai-kit/root" ]; then
  PREV_ROOT="$(tr -d '[:space:]' < "${HOME}/.config/ai-kit/root")"
fi
# An empty PREV_ROOT would make the "$PREV_ROOT"/* case arm read as /*, which
# matches every absolute path — including links belonging to other tools.
[ -n "$PREV_ROOT" ] || PREV_ROOT="//no-previous-root"

write_ai_kit_root_config "$AIKIT"

# Symlink every *.md file (top-level, not recursive) from $src_root into $target.
# Used for slash commands and subagents — each entry is a single file, not a directory.
install_files_to() {
  local src_root="$1"
  local target="$2"
  local src_real
  if [ ! -d "$src_root" ]; then
    return 0
  fi
  src_real="$(cd "$src_root" && pwd -P)"
  mkdir -p "$target"
  # Reap ai-kit links whose target moved. Includes orphans this run will not
  # relink (renamed or removed entries), which would otherwise stay dead
  # forever — the loop below only ever visits names that still exist in the
  # source tree, and a dead link there reads as "existing entry, skip".
  for dead in "$target"/*.md; do
    [ -L "$dead" ] && [ ! -e "$dead" ] || continue
    was="$(readlink "$dead")"
    case "$was" in
      */ai-kit/*|"$PREV_ROOT"/*)
        rm -f "$dead"
        echo "Removed dead link $(basename "$dead") (was -> $was)"
        ;;
    esac
  done
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

# Three refusals write nothing; detection then decides, as without a TTY.
if [ ! -f "$(aikit_hosts_file)" ] && [ -t 0 ]; then
  detected="$(aikit_hosts | paste -sd, -)"
  for _ in 1 2 3; do
    printf 'Which agents do you use? (claude,cursor,copilot,codex,gemini) [%s]: ' "$detected"
    read -r answer || answer=""
    if write_aikit_hosts "${answer:-$detected}"; then
      echo "Saved to ~/.config/ai-kit/hosts"
      break
    fi
  done
  echo ""
fi
HOSTS="$(aikit_hosts)"
CLAUDE_HOST=false
grep -qx claude <<<"$HOSTS" && CLAUDE_HOST=true

PREFER_PLUGIN_MARKER="${HOME}/.config/ai-kit/prefer-plugin"
PREFER_PLUGIN=false
if [ -f "$PREFER_PLUGIN_MARKER" ]; then
  PREFER_PLUGIN=true
fi

if [ "$CLAUDE_HOST" = false ]; then
  echo "=== Claude Code — skipped (not in ~/.config/ai-kit/hosts, or ~/.claude absent) ==="
elif [ "$PREFER_PLUGIN" = true ]; then
  echo "=== Claude Code skills — skipped (prefer-plugin marker) ==="
  echo "  Install via /plugin install ai@yusufkaracaburun to get /ai:* skills."
else
  echo "=== Claude Code skills (~/.claude/skills) ==="
  install_dir_to "$PRIMITIVES/skills" "${HOME}/.claude/skills"
fi

echo ""
if aikit_agents_skills_wanted; then
  echo "=== Cursor, Copilot and Claude Code legacy (~/.agents/skills) ==="
  install_dir_to "$PRIMITIVES/skills" "${HOME}/.agents/skills"
  prune_cursor_global_skills "$PRIMITIVES/skills"
else
  echo "=== ~/.agents/skills — no host reads it; ai-kit links removed ==="
  prune_aikit_skill_links "${HOME}/.agents/skills" "$PRIMITIVES/skills"
fi

if [ "$CLAUDE_HOST" = true ]; then
  echo ""
  if [ "$PREFER_PLUGIN" = true ]; then
    echo "=== Claude Code subagents — skipped (prefer-plugin marker) ==="
    echo "  Install via /plugin install ai@yusufkaracaburun to get explore/reviewer/qa-runner/verifier/builder/designer."
  else
    echo "=== Claude Code subagents (~/.claude/agents) ==="
    install_files_to "$PRIMITIVES/agents" "${HOME}/.claude/agents"
  fi

  echo ""
  if [ "$PREFER_PLUGIN" = true ]; then
    echo "=== Claude Code slash commands — skipped (prefer-plugin marker) ==="
    echo "  Install via /plugin install ai@yusufkaracaburun to get /ai:doctor etc."
  else
    echo "=== Claude Code slash commands (~/.claude/commands) ==="
    install_files_to "$PRIMITIVES/commands" "${HOME}/.claude/commands"
  fi
fi

if grep -qx cursor <<<"$HOSTS"; then
  echo ""
  echo "=== Cursor slash commands (~/.cursor/commands) ==="
  install_files_to "$PRIMITIVES/commands" "${HOME}/.cursor/commands"
fi

echo ""
echo "Saved ai-kit root to ~/.config/ai-kit/root"
echo "  AI_KIT_ROOT=$AIKIT"
echo ""
echo "Done. Run /ai:setup in any project to configure."
