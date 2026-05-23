#!/usr/bin/env bash
# Toggle the machine-wide "prefer plugin install for Claude Code commands"
# opt-out. When the marker is present, install-global.sh skips linking
# `workflow/commands/*.md` into `~/.claude/commands/`, so commands are only
# available via `/plugin install ai@yusufkaracaburun` and surface under
# the `/ai:` namespace.
#
# Cursor linking is unaffected — Cursor has no plugin-namespace concept,
# so symlinking into `~/.cursor/commands/` is the only path that works
# there.
set -euo pipefail

OPT_OUT_FILE="${HOME}/.config/ai-kit/prefer-plugin"

usage() {
  cat <<USAGE
Usage: $0 [on|off|status]

  on      Create ${OPT_OUT_FILE} — install-global.sh stops linking
          ~/.claude/commands/. Use /plugin install ai@yusufkaracaburun
          to get /ai:doctor etc. instead of bare /doctor.
  off     Remove the marker. Symlink-install resumes linking
          ~/.claude/commands/ on the next install / update.
  status  Print whether the opt-out is currently active. (Default.)

Cursor (~/.cursor/commands/) is unaffected by this marker — Cursor has
no plugin-namespace concept and must keep its symlinks for slash
commands to work.
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
    echo "install-global.sh will skip linking ~/.claude/commands/ on next run."
    echo "Existing bare-name symlinks in ~/.claude/commands/ are NOT removed —"
    echo "drop them by hand if you want a clean state:"
    echo ""
    echo "  for cmd in doctor status which no-globals upgrade followup prefer-plugin; do"
    echo "    rm -f ~/.claude/commands/\$cmd.md"
    echo "  done"
    echo ""
    echo "Then install the plugin for /ai:<command> support:"
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
