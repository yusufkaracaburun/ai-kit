#!/usr/bin/env bash
# autonomous-queue.sh — read the ready-for-agent issue queue for autonomous.
# Spike: docs/spikes/ai:autonomous-ralph.md  (tracks #17 and #18).
set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $0 next [--json] [--repo OWNER/REPO]

Print the oldest open issue labeled "ready-for-agent".

Output (default):  <issue#>\\t<title>
Output (--json):   {"issue": <n>, "title": "..."}  or  null

Empty queue: empty stdout, exit 0 (so callers can detect with [ -z "\$out" ]).
Missing gh CLI: stderr message, exit 3.
EOF
  exit "${1:-1}"
}

JSON_OUT=false
REPO=""
CMD=""
while [ $# -gt 0 ]; do
  case "$1" in
    next)        CMD="next"; shift ;;
    --json)      JSON_OUT=true; shift ;;
    --repo)      [ $# -ge 2 ] || usage; REPO="$2"; shift 2 ;;
    -h|--help)   usage 0 ;;
    *)           echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -z "$CMD" ] && usage

command -v gh >/dev/null 2>&1 \
  || { echo "gh CLI not found in PATH" >&2; exit 3; }

# shellcheck disable=SC2054  # `number,title,updatedAt` is a gh --json arg value, not a bash array literal.
GH_ARGS=(issue list --label ready-for-agent --state open --json number,title,updatedAt)
[ -n "$REPO" ] && GH_ARGS+=(--repo "$REPO")

RAW="$(gh "${GH_ARGS[@]}")"

RAW="$RAW" JSON_OUT="$JSON_OUT" python3 - <<'PY'
import json, os, sys
raw = os.environ.get("RAW") or "[]"
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"autonomous-queue: invalid JSON from gh: {e}", file=sys.stderr)
    sys.exit(4)
if not isinstance(data, list):
    print("autonomous-queue: expected JSON array from gh", file=sys.stderr)
    sys.exit(4)
data.sort(key=lambda i: i.get("updatedAt", ""))
is_json = os.environ.get("JSON_OUT") == "true"
if not data:
    if is_json:
        print("null")
    sys.exit(0)
top = data[0]
if is_json:
    print(json.dumps({"issue": top["number"], "title": top["title"]}))
else:
    print(f"{top['number']}\t{top['title']}")
PY
