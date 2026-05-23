#!/usr/bin/env bash
# autonomous-heartbeat.sh — periodic liveness ticks for /ai:autonomous.
# Spike: docs/spikes/ai:autonomous-ralph.md  (tracks #17, #38).
#
# Appends one `<iso-ts>\t<issue#>\theartbeat\t<state>` line per INTERVAL
# seconds to PROGRESS_FILE while the parent skill is alive. Designed to
# run as `& disown` from inside the skill, killed via trap on EXIT.
#
# Distinguishes "LLM in long thinking pause" (heartbeats continue) from
# "process gone / runner crashed" (heartbeats stop).
set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $0 <issue#> <progress-file> [--interval N]

  <issue#>         issue number being processed
  <progress-file>  absolute or relative path to .ai-kit/autonomous/progress.txt
  --interval N     seconds between ticks (default 60)

Run as: bash "\$AI_KIT_ROOT/bin/autonomous-heartbeat.sh" <n> <path> &
        HEARTBEAT_PID=\$!
        trap 'kill "\$HEARTBEAT_PID" 2>/dev/null' EXIT
EOF
  exit "${1:-1}"
}

INTERVAL=60
ISSUE=""
PROGRESS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --interval)  [ $# -ge 2 ] || usage; INTERVAL="$2"; shift 2 ;;
    -h|--help)   usage 0 ;;
    *)
      if [ -z "$ISSUE" ]; then ISSUE="$1"; shift
      elif [ -z "$PROGRESS" ]; then PROGRESS="$1"; shift
      else echo "Unexpected argument: $1" >&2; usage; fi
      ;;
  esac
done

[ -z "$ISSUE" ] && usage
[ -z "$PROGRESS" ] && usage
[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "Issue must be numeric: $ISSUE" >&2; exit 2; }
[[ "$INTERVAL" =~ ^[0-9]+$ ]] || { echo "Interval must be numeric: $INTERVAL" >&2; exit 2; }

PROGRESS_DIR="$(dirname "$PROGRESS")"
[ -d "$PROGRESS_DIR" ] || mkdir -p "$PROGRESS_DIR"

# Clean exit on SIGTERM / SIGINT — drop a final `heartbeat stopped` line
# so post-mortem readers see the helper exited deliberately.
trap 'TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; printf "%s\t%s\theartbeat\tstopped\n" "$TS" "$ISSUE" >> "$PROGRESS" 2>/dev/null || true; exit 0' TERM INT

while true; do
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf "%s\t%s\theartbeat\tbrewing\n" "$TS" "$ISSUE" >> "$PROGRESS"
  sleep "$INTERVAL"
done
