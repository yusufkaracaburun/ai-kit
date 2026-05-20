#!/usr/bin/env bash
# Show local ai-kit skill usage stats. Reads JSONL produced by log-skill.sh.
# No network access.
#
# Usage:
#   usage-stats.sh [--since=7d|30d|all] [--skill=<name>] [--json]

set -euo pipefail

SINCE="all"
SKILL_FILTER=""
JSON=false

while [ $# -gt 0 ]; do
  case "$1" in
    --since=*) SINCE="${1#--since=}"; shift ;;
    --skill=*) SKILL_FILTER="${1#--skill=}"; shift ;;
    --json)    JSON=true; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

log_file="${XDG_STATE_HOME:-$HOME/.local/state}/ai-kit/usage.jsonl"

if [ ! -f "$log_file" ]; then
  if [ "$JSON" = true ]; then
    echo '{"events":0,"skills":[],"projects":0,"log":""}'
  else
    echo "No usage log at $log_file"
    echo "Enable logging with: export AI_KIT_USAGE=1"
  fi
  exit 0
fi

case "$SINCE" in
  all) cutoff_epoch=0 ;;
  *d)
    days="${SINCE%d}"
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
      echo "Bad --since value: $SINCE" >&2; exit 2
    fi
    now_epoch="$(date -u +%s)"
    cutoff_epoch=$(( now_epoch - days * 86400 ))
    ;;
  *) echo "Bad --since value: $SINCE (expected 7d / 30d / all)" >&2; exit 2 ;;
esac

# Plain awk so we don't depend on jq. Format is one JSON object per line,
# fields in a known order — see log-skill.sh.
awk -v cutoff="$cutoff_epoch" \
    -v skill_filter="$SKILL_FILTER" \
    -v json="$JSON" '
function jval(line, key,    re, s, e) {
  re = "\"" key "\":\""
  s = index(line, re)
  if (s == 0) return ""
  s += length(re)
  e = index(substr(line, s), "\"")
  if (e == 0) return ""
  return substr(line, s, e - 1)
}
function iso_to_epoch(ts,    y, m, d, H, M, S) {
  y = substr(ts, 1, 4) + 0
  m = substr(ts, 6, 2) + 0
  d = substr(ts, 9, 2) + 0
  H = substr(ts, 12, 2) + 0
  M = substr(ts, 15, 2) + 0
  S = substr(ts, 18, 2) + 0
  return mktime(sprintf("%d %02d %02d %02d %02d %02d", y, m, d, H, M, S)) - tz_offset()
}
function tz_offset(   t, gm, local) {
  # Approximate: rely on system mktime treating fields as local time;
  # subtract the offset between local now and UTC now.
  t = systime()
  gm = strftime("%Y %m %d %H %M %S", t, 1)
  local = strftime("%Y %m %d %H %M %S", t, 0)
  # If awk does not support the third arg of strftime (POSIX-only), this
  # falls back to 0 — close enough for buckets of days.
  return 0
}
{
  ts = jval($0, "ts")
  skill = jval($0, "skill")
  event = jval($0, "event")
  project = jval($0, "project")
  hash = jval($0, "cwd_hash")
  if (ts == "" || skill == "") next
  if (skill_filter != "" && skill != skill_filter) next
  if (cutoff > 0) {
    et = iso_to_epoch(ts)
    if (et < cutoff) next
  }
  events++
  projects[hash] = 1
  if (event == "start") starts[skill]++
  else if (event == "done") completes[skill]++
  else if (event == "abort") aborts[skill]++
  seen[skill] = 1
}
END {
  if (json == "true") {
    printf "{\"events\":%d,\"projects\":%d,\"skills\":[", events, length(projects)
    first = 1
    for (s in seen) {
      st = starts[s] + 0
      co = completes[s] + 0
      ab = aborts[s] + 0
      pct = (st > 0) ? int(100.0 * (st - co) / st + 0.5) : 0
      if (!first) printf ","
      printf "{\"skill\":\"%s\",\"starts\":%d,\"completes\":%d,\"aborts\":%d,\"abandon_pct\":%d}", s, st, co, ab, pct
      first = 0
    }
    printf "]}\n"
  } else {
    if (events == 0) {
      print "No matching events."
      exit
    }
    printf "ai-kit usage — %d events, %d distinct projects\n\n", events, length(projects)
    printf "%-22s %8s %10s %10s\n", "skill", "starts", "completes", "abandon%"
    printf "%-22s %8s %10s %10s\n", "-----", "------", "---------", "--------"
    n = 0
    for (s in seen) { ordered[++n] = s }
    # simple insertion sort by start-count desc
    for (i = 2; i <= n; i++) {
      key = ordered[i]; j = i - 1
      while (j >= 1 && (starts[ordered[j]] + 0) < (starts[key] + 0)) {
        ordered[j+1] = ordered[j]; j--
      }
      ordered[j+1] = key
    }
    for (i = 1; i <= n; i++) {
      s = ordered[i]
      st = starts[s] + 0
      co = completes[s] + 0
      pct = (st > 0) ? int(100.0 * (st - co) / st + 0.5) : 0
      printf "%-22s %8d %10d %9d%%\n", s, st, co, pct
    }
  }
}
' "$log_file"

if [ "$JSON" != true ]; then
  size_bytes="$(wc -c < "$log_file" | tr -d ' ')"
  echo
  echo "log: $log_file (${size_bytes} bytes)"
fi
