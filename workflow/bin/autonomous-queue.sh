#!/usr/bin/env bash
# autonomous-queue.sh — read the ready-for-agent issue queue for autonomous.
# Spike: docs/spikes/ai:autonomous-ralph.md  (tracks #17 and #18).
set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $0 next [--json] [--repo OWNER/REPO] [--log FILE]

Print the oldest open issue labeled with the ready-for-agent label
(read from docs/agents/triage-labels.md, default "ready-for-agent").
An issue an open PR closes is skipped, and so is an idea card: its body has
every ## heading of the repo's or the kit's idea template (two or more) and no
Definition of Done. Each skip appends a progress.txt line to --log FILE (stderr without
it): <ts>\\t<issue#>\\tskip\\topen-pr=<PR#>|idea-card

Output (default):  <issue#>\\t<title>
Output (--json):   {"issue": <n>, "title": "..."}  or  null

Empty queue: empty stdout, exit 0 (so callers can detect with [ -z "\$out" ]).
Missing gh CLI: stderr message, exit 3.
EOF
  exit "${1:-1}"
}

JSON_OUT=false
REPO=""
LOG=""
CMD=""
while [ $# -gt 0 ]; do
  case "$1" in
    next)        CMD="next"; shift ;;
    --json)      JSON_OUT=true; shift ;;
    --repo)      [ $# -ge 2 ] || usage; REPO="$2"; shift 2 ;;
    --log)       [ $# -ge 2 ] || usage; LOG="$2"; shift 2 ;;
    -h|--help)   usage 0 ;;
    *)           echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -z "$CMD" ] && usage

command -v gh >/dev/null 2>&1 \
  || { echo "gh CLI not found in PATH" >&2; exit 3; }

# Same lookup as the autonomous skill: the tracker string mapped to the role.
READY_LABEL="$(awk -F'|' '$2 ~ /`ready-for-agent`/ {gsub(/^ +| +$|`/, "", $3); print $3}' docs/agents/triage-labels.md 2>/dev/null || true)"
READY_LABEL="${READY_LABEL:-ready-for-agent}"

# shellcheck disable=SC2054  # `number,title,updatedAt,body` is a gh --json arg value, not a bash array literal.
GH_ARGS=(issue list --label "$READY_LABEL" --state open --json number,title,updatedAt,body --limit 200)
[ -n "$REPO" ] && GH_ARGS+=(--repo "$REPO")

RAW="$(gh "${GH_ARGS[@]}")"
PRS="[]"
if [ "$(printf '%s' "$RAW" | tr -d '[:space:]')" != "[]" ]; then
  # shortcut: closingIssuesReferences only fills for PRs into the default branch, so PRs into an epic or target_branch are not skipped; match the PR body when that flow needs it.
  # shellcheck disable=SC2054
  PR_ARGS=(pr list --state open --json number,closingIssuesReferences --limit 200)
  [ -n "$REPO" ] && PR_ARGS+=(--repo "$REPO")
  PRS="$(gh "${PR_ARGS[@]}")"
fi

TEMPLATES="$(cd "$(dirname "$0")/../context/templates/github/ISSUE_TEMPLATE" && pwd)"

# RAW goes in as a file: 200 issue bodies outgrow the size limit of an env var.
PRS="$PRS" LOG="$LOG" JSON_OUT="$JSON_OUT" python3 - <(printf '%s' "$RAW") "$TEMPLATES" <<'PY'
import datetime, glob
import json, os, re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    raw = f.read() or "[]"
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"autonomous-queue: invalid JSON from gh: {e}", file=sys.stderr)
    sys.exit(4)
if not isinstance(data, list):
    print("autonomous-queue: expected JSON array from gh", file=sys.stderr)
    sys.exit(4)
try:
    prs = json.loads(os.environ.get("PRS") or "[]")
except json.JSONDecodeError as e:
    print(f"autonomous-queue: invalid PR JSON from gh: {e}", file=sys.stderr)
    sys.exit(4)
open_pr = {}
for pr in prs:
    for ref in pr.get("closingIssuesReferences") or []:
        open_pr.setdefault(ref.get("number"), pr.get("number"))


def headings(text):
    h2s = re.findall(r"^##[ \t]+(.+?)[ \t\r]*$", text or "", re.M)
    return {re.sub(r"\s*\([^)]*\)$", "", h).lower() for h in h2s}


idea_templates = []
for folder in (".github/ISSUE_TEMPLATE", sys.argv[2]):
    for path in glob.glob(f"{folder}/idea.md") + glob.glob(f"{folder}/idea.*.md"):
        with open(path, encoding="utf-8") as f:
            template = headings(f.read())
        # One heading is too weak a signal to skip a card on.
        if len(template) > 1:
            idea_templates.append(template)


def is_idea(issue):
    have = headings(issue.get("body"))
    return "definition of done" not in have and any(t <= have for t in idea_templates)


data.sort(key=lambda i: i.get("updatedAt", ""))
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
log = open(os.environ["LOG"], "a") if os.environ.get("LOG") else sys.stderr
queue = []
for i in data:
    if i["number"] in open_pr:
        print(f"{ts}\t{i['number']}\tskip\topen-pr={open_pr[i['number']]}", file=log)
    elif is_idea(i):
        print(f"{ts}\t{i['number']}\tskip\tidea-card", file=log)
    else:
        queue.append(i)
is_json = os.environ.get("JSON_OUT") == "true"
if not queue:
    if is_json:
        print("null")
    sys.exit(0)
top = queue[0]
if is_json:
    print(json.dumps({"issue": top["number"], "title": top["title"]}))
else:
    print(f"{top['number']}\t{top['title']}")
PY
