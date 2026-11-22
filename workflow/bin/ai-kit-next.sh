#!/usr/bin/env bash
# ai-kit-next.sh — ranked "what to do next" list for the current project.
#
# Combines three data sources:
#   1. GitHub issues (priority via the Priority issue field, else P0-P3
#      labels; status via the project Status field, else status:in-progress +
#      ready-for-agent labels; plus epic/* + area/* labels).
#   2. docs/roadmap.md (or ROADMAP.md / .planning/roadmap.md) entries that
#      reference a GH issue, AND entries that don't (roadmap-only TODOs).
#   3. .ai-kit-setup deferred branches (e.g. automation_recommender: deferred).
#
# Scoring per item:
#   P0 = 1000, P1 = 100, P2 = 10, P3 = 1; unprioritised roadmap = 5.
#   Priority issue field Urgent/High/Medium/Low = P0/P1/P2/P3, wins over P labels.
#   +50  status:in-progress or Status Doing  (finish before start)
#   +20  ready-for-agent or Status Next       (queue-drainable)
#   Status Blocked or Done: left out of the list.
#   Doing or Next with needs-triage or needs-info: one warning line, ranking unchanged.
#   +10  area/* matches current branch name
#   -1   per week since last update (stale penalty)
#
# Exits 0 even when empty (informational tool, not a gate).
#
# Usage:
#   ai-kit-next.sh [PATH] [--limit N] [--no-gh] [--no-roadmap] [--json]
#
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

TARGET="$(pwd)"
LIMIT=10
NO_GH=false
NO_ROADMAP=false
JSON_OUT=false

usage() {
  cat <<USAGE
Usage: $0 [PATH] [--limit N] [--no-gh] [--no-roadmap] [--json]

  PATH         project root (default: \$PWD)
  --limit N    max items in output (default: 10)
  --no-gh      skip GitHub issue lookup
  --no-roadmap skip roadmap.md parse
  --json       emit machine-readable JSON instead of text

Sources combined:
  - gh issue list --state open  (P0-P3 + status:in-progress + ready-for-agent)
  - Priority issue field + project Status field via gh api graphql (labels as fallback)
  - <PATH>/docs/roadmap.md  (or ROADMAP.md, .planning/roadmap.md)
  - <PATH>/.ai-kit-setup deferred branches
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --no-gh) NO_GH=true; shift ;;
    --no-roadmap) NO_ROADMAP=true; shift ;;
    --json) JSON_OUT=true; shift ;;
    -*) echo "Unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [ ! -d "$1" ]; then
        echo "Not a directory: $1" >&2; exit 2
      fi
      TARGET="$(cd "$1" && pwd)"
      shift
      ;;
  esac
done

# Resolve sources.
GH_JSON=""
if [ "$NO_GH" = false ] && command -v gh >/dev/null 2>&1 && (cd "$TARGET" && git rev-parse --git-dir >/dev/null 2>&1); then
  # gh fails silently if no remote or no auth — that's fine, we just emit "[]".
  GH_JSON="$(cd "$TARGET" && gh issue list --state open --limit 100 --json number,title,labels,updatedAt,url,assignees 2>/dev/null || echo '[]')"
  # Priority is an issue field, Status a project item field. Separate queries: Status needs the
  # read:project scope, and a failed query falls back to labels without taking the other down.
  # shortcut: first 100 open issues only, page with pageInfo once a repo has more.
  # shellcheck disable=SC2016
  PRIORITY_QUERY='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){issues(states:OPEN,first:100,orderBy:{field:CREATED_AT,direction:DESC}){nodes{number issueFieldValues(first:10){nodes{... on IssueFieldSingleSelectValue{name field{... on IssueFieldSingleSelect{name}}}}}}}}}'
  # shellcheck disable=SC2016
  STATUS_QUERY='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){issues(states:OPEN,first:100,orderBy:{field:CREATED_AT,direction:DESC}){nodes{number projectItems(first:10){nodes{status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}} projectsV2(first:10){nodes{id}}}}}}'
  PRIORITY_JSON=$(cd "$TARGET" && gh api graphql -F owner='{owner}' -F name='{repo}' -f query="$PRIORITY_QUERY" 2>/dev/null) || PRIORITY_JSON='{}'
  STATUS_JSON=$(cd "$TARGET" && gh api graphql -F owner='{owner}' -F name='{repo}' -f query="$STATUS_QUERY" 2>/dev/null) || STATUS_JSON='{}'
  # projectItems hides cards on a board of another owner (org board, user repo); read those boards' own items.
  BOARD_ARGS=()
  while IFS= read -r id; do [ -z "$id" ] || BOARD_ARGS+=(-f "ids[]=$id"); done < <(STATUS_JSON="$STATUS_JSON" python3 -c '
import json, os
try:
    issues = json.loads(os.environ["STATUS_JSON"])["data"]["repository"]["issues"]["nodes"]
except (ValueError, KeyError, TypeError):
    issues = []
nodes = lambda o, k: ((o or {}).get(k) or {}).get("nodes") or []
print("\n".join(sorted({p["id"] for n in issues if not nodes(n, "projectItems") for p in nodes(n, "projectsV2") if p})))
' 2>/dev/null)
  BOARD_JSON='{}'
  if [ ${#BOARD_ARGS[@]} -gt 0 ]; then
    # shortcut: first 100 open cards per board in a column that changes ranking; page once a board has more.
    # shellcheck disable=SC2016
    BOARD_QUERY='query($ids:[ID!]!,$q:String!){nodes(ids:$ids){... on ProjectV2{items(first:100,query:$q){nodes{content{... on Issue{number}} status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}'
    BOARD_JSON=$(cd "$TARGET" && gh api graphql "${BOARD_ARGS[@]}" -F q='repo:{owner}/{repo} is:open status:Doing,Next,Blocked,Done' -f query="$BOARD_QUERY" 2>/dev/null) || BOARD_JSON='{}'
  fi
else
  GH_JSON='[]'
  PRIORITY_JSON='{}'
  STATUS_JSON='{}'
  BOARD_JSON='{}'
fi

ROADMAP_FILE=""
if [ "$NO_ROADMAP" = false ]; then
  for candidate in "$TARGET/docs/roadmap.md" "$TARGET/ROADMAP.md" "$TARGET/.planning/roadmap.md"; do
    if [ -f "$candidate" ]; then
      ROADMAP_FILE="$candidate"
      break
    fi
  done
fi

MARKER_FILE=""
if [ -f "$TARGET/.ai-kit-setup" ]; then
  MARKER_FILE="$TARGET/.ai-kit-setup"
fi

CURRENT_BRANCH=""
if (cd "$TARGET" && git rev-parse --git-dir >/dev/null 2>&1); then
  CURRENT_BRANCH="$(cd "$TARGET" && git symbolic-ref --short HEAD 2>/dev/null || echo '')"
fi

# Hand off to python3 ranker.
GH_JSON="$GH_JSON" \
PRIORITY_JSON="$PRIORITY_JSON" \
STATUS_JSON="$STATUS_JSON" \
BOARD_JSON="$BOARD_JSON" \
ROADMAP_FILE="$ROADMAP_FILE" \
MARKER_FILE="$MARKER_FILE" \
CURRENT_BRANCH="$CURRENT_BRANCH" \
LIMIT="$LIMIT" \
TARGET="$TARGET" \
JSON_OUT="$JSON_OUT" \
python3 - <<'PY'
import json, os, re, sys
from datetime import datetime, timezone

LIMIT = int(os.environ.get("LIMIT", "10"))
JSON_OUT = os.environ.get("JSON_OUT") == "true"
TARGET = os.environ.get("TARGET") or "."
CURRENT_BRANCH = os.environ.get("CURRENT_BRANCH") or ""

P_SCORE = {"P0": 1000, "P1": 100, "P2": 10, "P3": 1}
P_LABEL_RE = re.compile(r"^P([0-3])(?:-|$)")

# --- 1. GH issues -----------------------------------------------------------
gh_raw = os.environ.get("GH_JSON") or "[]"
try:
    gh_issues = json.loads(gh_raw)
except json.JSONDecodeError:
    gh_issues = []

def parse_iso(s):
    if not s:
        return None
    s = s.rstrip("Z")
    try:
        return datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
    except ValueError:
        return None

def label_names(issue):
    return [l.get("name", "") for l in issue.get("labels", [])]

FIELD_PRIORITY = {"Urgent": "P0", "High": "P1", "Medium": "P2", "Low": "P3"}

def issue_nodes(env):
    try:
        return json.loads(os.environ.get(env) or "{}")["data"]["repository"]["issues"]["nodes"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return []

def project_fields():
    """Map issue number -> (Priority issue field tags, project item status names)."""
    out = {}
    for n in issue_nodes("PRIORITY_JSON"):
        if not n:
            continue
        prios = {FIELD_PRIORITY[v["name"]] for v in (n.get("issueFieldValues") or {}).get("nodes") or []
                 if v and (v.get("field") or {}).get("name") == "Priority" and v.get("name") in FIELD_PRIORITY}
        out.setdefault(n.get("number"), (set(), set()))[0].update(prios)
    for n in issue_nodes("STATUS_JSON"):
        if not n:
            continue
        statuses = {(it.get("status") or {}).get("name") for it in (n.get("projectItems") or {}).get("nodes") or [] if it}
        out.setdefault(n.get("number"), (set(), set()))[1].update(statuses - {None})
    try:
        boards = json.loads(os.environ.get("BOARD_JSON") or "{}")["data"]["nodes"]
    except (json.JSONDecodeError, KeyError, TypeError):
        boards = []
    for b in boards:
        for it in ((b or {}).get("items") or {}).get("nodes") or []:
            name = ((it or {}).get("status") or {}).get("name")
            number = ((it or {}).get("content") or {}).get("number")
            if name and number:
                out.setdefault(number, (set(), set()))[1].add(name)
    return out

fields = project_fields()
items = []
warnings = []
gh_issue_numbers = set()
now = datetime.now(timezone.utc)

for iss in gh_issues:
    labels = label_names(iss)
    field_prios, statuses = fields.get(iss.get("number"), (set(), set()))
    gh_issue_numbers.add(iss.get("number"))
    columns, clashes = sorted(statuses & {"Doing", "Next"}), sorted(set(labels) & {"needs-triage", "needs-info"})
    if columns and clashes:
        warnings.append(f"  warning: #{iss.get('number')} is in {' and '.join(columns)} but labelled {', '.join(clashes)}")
    if statuses & {"Blocked", "Done"}:
        continue
    p_score = 0
    p_tag = None
    tags = field_prios or {f"P{m.group(1)}" for m in map(P_LABEL_RE.match, labels) if m}
    for tag in tags:
        if P_SCORE[tag] > p_score:
            p_tag, p_score = tag, P_SCORE[tag]
    if p_score == 0:
        p_score = 5  # default for unlabelled GH issues
        p_tag = "P?"
    score = p_score
    in_progress = "status:in-progress" in labels or "Doing" in statuses
    ready = "ready-for-agent" in labels or "Next" in statuses
    if in_progress:
        score += 50
    if ready:
        score += 20
    area = next((l for l in labels if l.startswith("area/")), None)
    epic = next((l for l in labels if l.startswith("epic/")), None)
    if area and CURRENT_BRANCH and area.split("/", 1)[1] in CURRENT_BRANCH:
        score += 10
    updated = parse_iso(iss.get("updatedAt"))
    if updated:
        weeks = max(0, (now - updated).days // 7)
        score -= weeks
    items.append({
        "kind": "gh",
        "number": iss.get("number"),
        "title": iss.get("title") or "",
        "priority": p_tag,
        "area": area,
        "epic": epic,
        "status_in_progress": in_progress,
        "ready_for_agent": ready,
        "url": iss.get("url"),
        "updated": iss.get("updatedAt"),
        "score": score,
    })

# --- 2. Roadmap entries -----------------------------------------------------
ROADMAP_FILE = os.environ.get("ROADMAP_FILE") or ""
roadmap_only = []
# Only count OPEN task checkboxes: "- [ ] …". Closed (`[x]`) and free prose
# bullets are skipped — too noisy otherwise.
OPEN_TASK_RE = re.compile(r"^\s*[-*]\s+\[\s\]\s+(.+?)\s*$")
in_code_block = False
if ROADMAP_FILE and os.path.isfile(ROADMAP_FILE):
    with open(ROADMAP_FILE) as f:
        for raw in f:
            line = raw.rstrip("\n")
            stripped_for_fence = line.strip()
            if stripped_for_fence.startswith("```"):
                in_code_block = not in_code_block
                continue
            if in_code_block:
                continue
            m = OPEN_TASK_RE.match(line)
            if not m:
                continue
            task = m.group(1)
            # If task references a GH issue we already have, skip duplicate
            issue_refs = [int(x.group(1)) for x in re.finditer(r"#(\d+)", task)]
            if any(n in gh_issue_numbers for n in issue_refs):
                continue
            # Priority hint
            p_tag = None
            pm = re.search(r"\bP([0-3])\b", task)
            if pm:
                p_tag = f"P{pm.group(1)}"
            score = P_SCORE.get(p_tag, 5)
            roadmap_only.append({
                "kind": "roadmap",
                "title": task[:140],
                "priority": p_tag,
                "score": score,
            })

items.extend(roadmap_only)

# --- 3. .ai-kit-setup deferred branches -------------------------------------
MARKER_FILE = os.environ.get("MARKER_FILE") or ""
if MARKER_FILE and os.path.isfile(MARKER_FILE):
    try:
        with open(MARKER_FILE) as f:
            marker = json.load(f)
    except (json.JSONDecodeError, OSError):
        marker = {}
    for k, v in (marker.get("branches") or {}).items():
        if v == "deferred":
            items.append({
                "kind": "deferred",
                "title": f"Setup branch: {k}",
                "priority": "P3",
                "score": 2,
            })

# --- Rank + output ----------------------------------------------------------
items.sort(key=lambda x: x.get("score", 0), reverse=True)
top = items[:LIMIT]

if JSON_OUT:
    print(json.dumps({"target": TARGET, "items": top, "total": len(items)}, indent=2))
    sys.exit(0)

if not top:
    print("ai-kit next — nothing open")
    print("")
    print("  No prioritised GH issues, no open roadmap entries, no deferred setup branches.")
    print("  If you think this is wrong: gh auth status; ls docs/roadmap.md")
    sys.exit(0)

print(f"ai-kit next — top {len(top)} for {os.path.basename(TARGET.rstrip('/'))} (of {len(items)} total)")
if CURRENT_BRANCH:
    print(f"  branch: {CURRENT_BRANCH}")
print("")
if warnings:
    print("\n".join(warnings))
    print("")
for i, it in enumerate(top, 1):
    p = it.get("priority") or "P?"
    if it["kind"] == "gh":
        flags = []
        if it.get("status_in_progress"):
            flags.append("in-progress")
        if it.get("ready_for_agent"):
            flags.append("ready-for-agent")
        area = it.get("area") or ""
        epic = it.get("epic") or ""
        flag_str = " ".join(flags)
        tags = " ".join(t for t in [area, epic] if t)
        head = f"  {i:>2}. [{p}] #{it['number']} {tags}".rstrip()
        print(f"{head}")
        print(f"      {it['title']}")
        meta = []
        if flag_str:
            meta.append(flag_str)
        if it.get("updated"):
            meta.append(f"updated {it['updated'][:10]}")
        meta.append(f"score {it['score']}")
        print(f"      ({', '.join(meta)})  {it.get('url') or ''}")
    elif it["kind"] == "roadmap":
        print(f"  {i:>2}. [{p}] roadmap-only")
        print(f"      {it['title']}")
        print(f"      (no GH issue — consider /ai:to-prd defer to open one)")
    elif it["kind"] == "deferred":
        print(f"  {i:>2}. [{p}] setup-deferred")
        print(f"      {it['title']}")
        print(f"      (revisit via /ai:setup re-run when ready)")
    print("")
PY
