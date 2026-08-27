#!/usr/bin/env bash
# Toggle the machine-wide opt-out for the SessionStart always-on rule
# injection hook (bin/hooks/session-rules-inject.sh, issue #144). When the
# marker is present, the hook exits silently without injecting anything —
# .claude/rules/ stays exactly as on-demand as it always was.
set -euo pipefail

OPT_OUT_FILE="${HOME}/.config/ai-kit/no-rule-injection"

usage() {
  cat <<USAGE
Usage: $0 [on|off|status]

  on      Create ${OPT_OUT_FILE} — session-rules-inject.sh no-ops on every
          SessionStart, in every project, on this machine.
  off     Remove the marker. Injection resumes on the next session.
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
    echo "Opt-out active: ${OPT_OUT_FILE}"
    echo "session-rules-inject.sh will no-op on every SessionStart until this is removed."
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
