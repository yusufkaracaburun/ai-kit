#!/usr/bin/env bash
# ai-kit-next.sh — ranked "what to do next" list for the current project.
#
# Combines three data sources:
#   1. GitHub issues (priority via P0-P3 labels installed by setup-gh-workflow,
#      plus epic/* + area/* + status:in-progress + ready-for-agent labels).
#   2. docs/roadmap.md (or ROADMAP.md / .planning/roadmap.md) entries that
#      reference a GH issue, AND entries that don't (roadmap-only TODOs).
#   3. .ai-kit-setup deferred branches (e.g. automation_recommender: deferred).
#
# Scoring per item:
#   P0 = 1000, P1 = 100, P2 = 10, P3 = 1; unprioritised roadmap = 5.
#   +50  status:in-progress         (finish before start)
#   +20  ready-for-agent             (queue-drainable)
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
else
  GH_JSON='[]'
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

items = []
gh_issue_numbers = set()
now = datetime.now(timezone.utc)

for iss in gh_issues:
    labels = label_names(iss)
    p_score = 0
    p_tag = None
    for lab in labels:
        m = P_LABEL_RE.match(lab)
        if m:
            p_tag = f"P{m.group(1)}"
            p_score = max(p_score, P_SCORE[p_tag])
    if p_score == 0:
        p_score = 5  # default for unlabelled GH issues
        p_tag = p_tag or "P?"
    score = p_score
    if "status:in-progress" in labels:
        score += 50
    if "ready-for-agent" in labels:
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
        "status_in_progress": "status:in-progress" in labels,
        "ready_for_agent": "ready-for-agent" in labels,
        "url": iss.get("url"),
        "updated": iss.get("updatedAt"),
        "score": score,
    })
    gh_issue_numbers.add(iss.get("number"))

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
    print("  No P-labelled GH issues, no open roadmap entries, no deferred setup branches.")
    print("  If you think this is wrong: gh auth status; ls docs/roadmap.md")
    sys.exit(0)

print(f"ai-kit next — top {len(top)} for {os.path.basename(TARGET.rstrip('/'))} (of {len(items)} total)")
if CURRENT_BRANCH:
    print(f"  branch: {CURRENT_BRANCH}")
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
