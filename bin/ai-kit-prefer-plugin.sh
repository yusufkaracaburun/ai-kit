#!/usr/bin/env bash
# Toggle the machine-wide "prefer plugin install for Claude Code" opt-out.
# When the marker is present, install-global.sh skips linking ai-kit's
# skills, subagents, and commands into ~/.claude/ — they then surface only
# via `/plugin install ai@yusufkaracaburun`, under the `/ai:` namespace.
#
# Cursor linking is unaffected — Cursor has no plugin-namespace concept,
# so symlinking into ~/.cursor/{skills,commands}/ is the only path that
# works there.
set -euo pipefail

OPT_OUT_FILE="${HOME}/.config/ai-kit/prefer-plugin"

usage() {
  cat <<USAGE
Usage: $0 [on|off|status]

  on      Create ${OPT_OUT_FILE} — install-global.sh stops linking
          ~/.claude/{skills,agents,commands}/. Use
          /plugin install ai@yusufkaracaburun to get /ai:* namespace
          (skills + subagents + slash commands).
  off     Remove the marker. Symlink-install resumes linking
          ~/.claude/{skills,agents,commands}/ on the next install / update.
  status  Print whether the opt-out is currently active. (Default.)

Cursor (~/.cursor/{skills,commands}/) is unaffected by this marker —
Cursor has no plugin-namespace concept and must keep its symlinks for
skills and slash commands to work.
USAGE
}

ACTION="${1:-status}"
case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  on)
    mkdir -p "$(dirname "$OPT_OUT_FILE")"
    : > "$OPT_OUT_FILE"
    echo "prefer-plugin opt-out active: ${OPT_OUT_FILE}"
    echo ""
    echo "install-global.sh will skip linking ~/.claude/{skills,agents,commands}/"
    echo "on next run. Existing bare-name symlinks are NOT removed — drop them"
    echo "by hand if you want a clean state:"
    echo ""
    echo "  # Skills + agents — only the ai-kit ones (others stay)"
    echo "  for d in ~/.claude/skills/* ~/.claude/agents/*; do"
    echo "    if [ -L \"\$d\" ] && readlink \"\$d\" | grep -q ai-kit; then rm -f \"\$d\"; fi"
    echo "  done"
    echo "  # Slash commands"
    echo "  for cmd in doctor status which no-globals upgrade prefer-plugin; do"
    echo "    rm -f ~/.claude/commands/\$cmd.md"
    echo "  done"
    echo ""
    echo "Then install the plugin for /ai:* support (skills + subagents + commands):"
    echo "  /plugin marketplace add yusufkaracaburun/marketplace"
    echo "  /plugin install ai@yusufkaracaburun"
    ;;
  off)
    if [ -f "$OPT_OUT_FILE" ]; then
      rm -f "$OPT_OUT_FILE"
      echo "prefer-plugin opt-out removed: ${OPT_OUT_FILE}"
    else
      echo "prefer-plugin opt-out already absent"
    fi
    ;;
  status)
    if [ -f "$OPT_OUT_FILE" ]; then
      echo "prefer-plugin: ON  (${OPT_OUT_FILE})"
      exit 0
    else
      echo "prefer-plugin: OFF (no marker at ${OPT_OUT_FILE})"
      exit 0
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage
    exit 1
    ;;
esac
