#!/usr/bin/env bash
# Toggle the machine-wide "skip global checks" opt-out used by ai-kit-doctor.sh.
# Does NOT affect /aikit-setup, bootstrap-project.sh, or any other script — those
# still let each project pick its own setup-mode (solo-both, project-only,
# etc.) independently.
set -euo pipefail

OPT_OUT_FILE="${HOME}/.config/ai-kit/no-globals"

usage() {
  cat <<USAGE
Usage: $0 [on|off|status]

  on      Create ${OPT_OUT_FILE} — doctor skips global checks by default.
  off     Remove the marker. Doctor checks globals as usual.
  status  Print whether the opt-out is currently active. (Default.)

Project-level setup-mode (in .ai-kit-setup) always wins over this marker —
projects that use globals stay correctly checked.
USAGE
}

ACTION="${1:-status}"
case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  on)
    mkdir -p "$(dirname "$OPT_OUT_FILE")"
    : > "$OPT_OUT_FILE"
    echo "Opt-out active: ${OPT_OUT_FILE}"
    echo "ai-kit-doctor.sh will skip global checks unless a project's marker says otherwise."
    ;;
  off)
    if [ -f "$OPT_OUT_FILE" ]; then
      rm -f "$OPT_OUT_FILE"
      echo "Opt-out removed: ${OPT_OUT_FILE}"
    else
      echo "Opt-out already absent"
    fi
    ;;
  status)
    if [ -f "$OPT_OUT_FILE" ]; then
      echo "Opt-out: ON  (${OPT_OUT_FILE})"
      exit 0
    else
      echo "Opt-out: OFF (no marker at ${OPT_OUT_FILE})"
      exit 0
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage
    exit 2
    ;;
esac
