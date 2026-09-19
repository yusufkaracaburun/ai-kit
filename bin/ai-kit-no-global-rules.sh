#!/usr/bin/env bash
# Toggle the machine-wide opt-out for ai-kit's global rules (ADR-0015):
# the ~/.claude/rules/ai-kit link that bin/hooks/global-rules-link.sh keeps
# pointing at the plugin's rules/ payload. Same shape as ai-kit-no-globals.sh.
set -euo pipefail

OPT_OUT_FILE="${HOME}/.config/ai-kit/no-global-rules"
LINK="${HOME}/.claude/rules/ai-kit"

usage() {
  cat <<USAGE
Usage: $0 [on|off|status]

  on      Create ${OPT_OUT_FILE} and remove ${LINK} — no ai-kit rule loads
          globally on this machine until the marker is removed.
  off     Remove the marker. The link is restored on the next session start.
  status  Print whether the opt-out is currently active. (Default.)

This is a machine-wide toggle, not per-project — there is no per-project
override. Uninstalling ai-kit is not required to turn this off.
USAGE
}

ACTION="${1:-status}"
case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  on)
    mkdir -p "$(dirname "$OPT_OUT_FILE")"
    : > "$OPT_OUT_FILE"
    [ -L "$LINK" ] && rm -f "$LINK"
    echo "Opt-out active: ${OPT_OUT_FILE}"
    echo "Global rules off — ${LINK} removed; the SessionStart hook will not recreate it."
    ;;
  off)
    if [ -f "$OPT_OUT_FILE" ]; then
      rm -f "$OPT_OUT_FILE"
      echo "Opt-out removed: ${OPT_OUT_FILE}"
      echo "Global rules resume on the next session start."
    else
      echo "Opt-out already absent"
    fi
    ;;
  status)
    if [ -f "$OPT_OUT_FILE" ]; then
      echo "Opt-out: ON  (${OPT_OUT_FILE})"
    else
      echo "Opt-out: OFF (no marker at ${OPT_OUT_FILE})"
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage
    exit 2
    ;;
esac
