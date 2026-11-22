#!/usr/bin/env bash
# ai-kit-issue-meta.sh: give one issue its type, Priority, board spot and board Status.
#
# Type: set when the repo offers issue types, else skipped.
# Priority: --priority, else the Priority the issue already has is kept, else the
#   --parent issue's Priority, else Medium. Set as
#   the Priority issue field; repos without that field get the P label instead.
# Board: the project the issue is on, else the one most open issues of the repo are
#   on; none found, skipped.
# Status: --status sets the card's Status column on that board, then removes labels
#   that clash with the column. Without --type only the card moves.
#
# Never fails the caller: API failures print one line on stderr and exit 0.
# Exits 2 only on bad arguments.
#
# Usage:
#   ai-kit-issue-meta.sh <issue-number|issue-url> --type Feature|Bug|Task
#                        [--priority Urgent|High|Medium|Low] [--parent <issue>]
#                        [--status Backlog|Next|Doing|Blocked|Done]
#   ai-kit-issue-meta.sh <issue-number|issue-url> --status Backlog|Next|Doing|Blocked|Done
#
set -uo pipefail

usage() {
  cat <<USAGE
Usage: $0 <issue-number|issue-url> --type Feature|Bug|Task [--priority Urgent|High|Medium|Low] [--parent <issue>] [--status <column>]
       $0 <issue-number|issue-url> --status Backlog|Next|Doing|Blocked|Done

  --type      Feature (epic, PRD, new functionality), Bug (fault), Task (slice, chore)
  --priority  explicit Priority; default: keep the issue's own, else the parent's, else Medium
  --parent    PRD or epic issue to inherit Priority from
  --status    board column to move the card to; drops labels that clash with it
USAGE
}

bad() { echo "issue-meta: $1" >&2; usage >&2; exit 2; }
note() { echo "issue-meta: $1" >&2; }
ERR_FILE=$(mktemp)
trap 'command rm -f "$ERR_FILE"' EXIT
# Notes a failure with the first line of the last gh call's stderr.
fail() {
  local err
  err=$(head -n 1 "$ERR_FILE")
  note "$1${err:+: $err}"
}

# Sets REF_OWNER, REF_NAME, REF_NUM; a bare number uses gh's {owner}/{repo} of the cwd repo.
parse_ref() {
  local url_re='^https://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/issues/([0-9]+)([/?#].*)?$'
  if [[ "$1" =~ $url_re ]]; then
    REF_OWNER="${BASH_REMATCH[1]}"; REF_NAME="${BASH_REMATCH[2]}"; REF_NUM="${BASH_REMATCH[3]}"
  elif [[ "$1" =~ ^#?([0-9]+)$ ]]; then
    REF_OWNER='{owner}'; REF_NAME='{repo}'; REF_NUM="${BASH_REMATCH[1]}"
  else
    return 1
  fi
}

ISSUE="" TYPE="" PRIORITY="" PARENT="" STATUS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --type) TYPE="${2:-}"; shift 2 || shift ;;
    --priority) PRIORITY="${2:-}"; shift 2 || shift ;;
    --parent) PARENT="${2:-}"; shift 2 || shift ;;
    --status) STATUS="${2:-}"; shift 2 || shift ;;
    -*) bad "unknown flag: $1" ;;
    *) [ -z "$ISSUE" ] || bad "one issue at a time"; ISSUE="$1"; shift ;;
  esac
done

[ -n "$ISSUE" ] || bad "missing issue"
[ -n "$TYPE$STATUS" ] || bad "need --type, --status or both"
case "$TYPE" in ""|Feature|Bug|Task) ;; *) bad "--type must be Feature, Bug or Task" ;; esac
case "$PRIORITY" in ""|Urgent|High|Medium|Low) ;; *) bad "--priority must be Urgent, High, Medium or Low" ;; esac
case "$STATUS" in ""|Backlog|Next|Doing|Blocked|Done) ;; *) bad "--status must be Backlog, Next, Doing, Blocked or Done" ;; esac
[ -n "$TYPE" ] || [ -z "$PRIORITY$PARENT" ] || bad "--priority and --parent need --type"
parse_ref "$ISSUE" || bad "not an issue number or URL: $ISSUE"
OWNER="$REF_OWNER" NAME="$REF_NAME" NUM="$REF_NUM"
if [ -n "$PARENT" ]; then
  parse_ref "$PARENT" || bad "not an issue number or URL: $PARENT"
  [ "$REF_OWNER" != '{owner}' ] || { REF_OWNER="$OWNER"; REF_NAME="$NAME"; }
fi

# Bare forms first: the label writer takes the last match, so new labels stay suffixed.
P_LABELS="P0=Urgent P1=High P2=Medium P3=Low P0-critical=Urgent P1-high=High P2-medium=Medium P3-low=Low"

# Prints the id paired with exactly name $1 in list $2: pairs split by \x1e, name and id by \x1f.
option_id() {
  local pair pairs
  IFS=$'\x1e' read -ra pairs <<<"$2"
  for pair in ${pairs[@]+"${pairs[@]}"}; do
    [ "${pair%%$'\x1f'*}" = "$1" ] && { echo "${pair#*$'\x1f'}"; return; }
  done
}

# Prints "itemId|statusFieldId|options" (option_id format) for the issue's card on $PROJECT_ID, read from
# the META reply's issue.projectItems or an addProjectV2ItemById reply in $1.
status_item() {
  ITEM_JSON="$1" PROJECT_ID="$PROJECT_ID" python3 -c '
import json, os
data = json.loads(os.environ["ITEM_JSON"]).get("data") or {}
issue = (data.get("repository") or {}).get("issue") or {}
items = ((issue.get("projectItems") or {}).get("nodes") or []) + [(data.get("addProjectV2ItemById") or {}).get("item")]
for item in items:
    project = (item or {}).get("project") or {}
    if project.get("id") == os.environ["PROJECT_ID"]:
        field = project.get("field") or {}
        print("|".join([item.get("id", ""), field.get("id", ""), "\x1e".join(o["name"] + "\x1f" + o["id"] for o in field.get("options") or [])]))
        break
' 2>/dev/null
}

# Prints "<Priority> field|label" for data.repository.issue in $1: the field value, else the P label.
priority_of() {
  ISSUE_JSON="$1" P_LABELS="$P_LABELS" python3 -c '
import json, os
issue = ((json.loads(os.environ["ISSUE_JSON"]).get("data") or {}).get("repository") or {}).get("issue") or {}
for v in (issue.get("issueFieldValues") or {}).get("nodes") or []:
    if (v.get("field") or {}).get("name") == "Priority":
        print(v.get("name"), "field"); raise SystemExit
labels = dict(p.split("=") for p in os.environ["P_LABELS"].split())
for l in (issue.get("labels") or {}).get("nodes") or []:
    if l.get("name") in labels:
        print(labels[l["name"]], "label"); raise SystemExit
' 2>/dev/null
}

ISSUE_PRIORITY_FIELDS='labels(first:100){nodes{name} pageInfo{hasNextPage}} issueFieldValues(first:10){nodes{... on IssueFieldSingleSelectValue{name field{... on IssueFieldSingleSelect{name}}}}}'
ITEM_FIELDS='id project{id field(name:"Status"){... on ProjectV2SingleSelectField{id options{id name}}}}'
# shellcheck disable=SC2016
META_QUERY='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){issueTypes(first:20){nodes{id name}} issueFields(first:20){nodes{... on IssueFieldSingleSelect{id name options{id name}}}} issues(states:OPEN,first:50,orderBy:{field:CREATED_AT,direction:DESC}){nodes{projectsV2(first:10){nodes{id}}}} issue(number:$number){id '"$ISSUE_PRIORITY_FIELDS"' projectItems(first:10){nodes{'"$ITEM_FIELDS"'}} projectsV2(first:10){nodes{id}}}}}'
if ! command -v python3 >/dev/null 2>&1; then
  note "python3 not found, nothing set"
  exit 0
fi
if ! META_JSON=$(gh api graphql -F owner="$OWNER" -F name="$NAME" -F number="$NUM" -f query="$META_QUERY" 2>"$ERR_FILE"); then
  fail "reading #$NUM failed, nothing set"
  exit 0
fi
# projectItems hides cards on a board of another owner (org board, user repo); projectsV2 lists every board.
# shortcut: board = most common project over the 50 newest open issues; page if repos outgrow that.
if ! PARSED=$(META_JSON="$META_JSON" TYPE="$TYPE" python3 -c '
import json, os
from collections import Counter
repo = (json.loads(os.environ["META_JSON"]).get("data") or {}).get("repository") or {}
nodes = lambda o, k: ((o or {}).get(k) or {}).get("nodes") or []
has_type = any(t.get("name") == os.environ["TYPE"] for t in nodes(repo, "issueTypes"))
field = next((f for f in nodes(repo, "issueFields") if f.get("name") == "Priority"), {})
options = "\x1e".join(o["name"] + "\x1f" + o["id"] for o in field.get("options") or [])
boards = Counter(p["id"] for n in nodes(repo, "issues") for p in nodes(n, "projectsV2") if p)
own = [p["id"] for p in nodes(repo.get("issue"), "projectsV2") if p]
board = max(own, key=lambda p: boards[p]) if own else (boards.most_common(1)[0][0] if boards else "")
print("|".join([(repo.get("issue") or {}).get("id", ""), "1" if has_type else "", field.get("id", ""), options, board, "1" if own else ""]))
' 2>/dev/null); then
  note "could not parse gh's reply for #$NUM, nothing set"
  exit 0
fi
IFS='|' read -r ISSUE_ID HAS_TYPE FIELD_ID OPTIONS PROJECT_ID ON_BOARD <<<"$PARSED"
if [ -z "${ISSUE_ID:-}" ]; then
  note "#$NUM not found, nothing set"
  exit 0
fi

DONE=() ADD_LABEL="" CLASH=""
if [ -z "$TYPE" ]; then
  :
elif [ -n "$HAS_TYPE" ]; then
  if gh api -X PATCH "repos/$OWNER/$NAME/issues/$NUM" -f type="$TYPE" >/dev/null 2>"$ERR_FILE"; then
    DONE+=("type $TYPE")
  else
    fail "setting type $TYPE failed"
  fi
else
  note "no issue types in this repo, type skipped"
fi

KEEP_PRIORITY=""
if [ -n "$TYPE" ] && [ -z "$PRIORITY" ]; then
  read -r OWN_PRIORITY OWN_SOURCE <<<"$(priority_of "$META_JSON")"
  if [ "${OWN_SOURCE:-}" = field ] || [ -z "$FIELD_ID" ]; then
    KEEP_PRIORITY="${OWN_PRIORITY:-}"
  else
    PRIORITY="${OWN_PRIORITY:-}"
  fi
  if [ -z "$KEEP_PRIORITY$PRIORITY" ] && [ -n "$PARENT" ]; then
    # shellcheck disable=SC2016
    PARENT_QUERY='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){issue(number:$number){'"$ISSUE_PRIORITY_FIELDS"'}}}'
    if PARENT_JSON=$(gh api graphql -F owner="$REF_OWNER" -F name="$REF_NAME" -F number="$REF_NUM" -f query="$PARENT_QUERY" 2>"$ERR_FILE"); then
      PRIORITY=$(priority_of "$PARENT_JSON")
      PRIORITY="${PRIORITY%% *}"
    else
      fail "parent $PARENT lookup failed, Priority defaults to Medium"
    fi
  fi
  PRIORITY="${PRIORITY:-Medium}"
fi

OPTION_ID=$(option_id "$PRIORITY" "$OPTIONS")
if [ -z "$TYPE" ]; then
  :
elif [ -n "$KEEP_PRIORITY" ]; then
  DONE+=("kept Priority $KEEP_PRIORITY")
elif [ -n "$FIELD_ID" ] && [ -n "$OPTION_ID" ]; then
  # shellcheck disable=SC2016
  SET_QUERY='mutation($issueId:ID!,$fieldId:ID!,$optionId:ID!){setIssueFieldValue(input:{issueId:$issueId,issueFields:[{fieldId:$fieldId,singleSelectOptionId:$optionId}]}){clientMutationId}}'
  if gh api graphql -f issueId="$ISSUE_ID" -f fieldId="$FIELD_ID" -f optionId="$OPTION_ID" -f query="$SET_QUERY" >/dev/null 2>"$ERR_FILE"; then
    DONE+=("Priority $PRIORITY")
  else
    fail "setting Priority $PRIORITY failed"
  fi
else
  ADD_LABEL=P3-low
  for pair in $P_LABELS; do
    [ "${pair#*=}" = "$PRIORITY" ] && ADD_LABEL="${pair%%=*}"
  done
  note "no Priority field or no $PRIORITY option, adding label $ADD_LABEL instead"
fi

if [ -n "$PROJECT_ID" ]; then
  IFS='|' read -r ITEM_ID STATUS_FIELD_ID STATUS_OPTIONS <<<"$(status_item "$META_JSON")"
  if [ -z "${ITEM_ID:-}" ]; then
    # Already on the board but hidden from projectItems: the add returns the existing card.
    # shellcheck disable=SC2016
    ADD_QUERY='mutation($projectId:ID!,$contentId:ID!){addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){item{'"$ITEM_FIELDS"'}}}'
    if ADD_JSON=$(gh api graphql -f projectId="$PROJECT_ID" -f contentId="$ISSUE_ID" -f query="$ADD_QUERY" 2>"$ERR_FILE"); then
      [ -n "$ON_BOARD" ] || DONE+=("board")
      IFS='|' read -r ITEM_ID STATUS_FIELD_ID STATUS_OPTIONS <<<"$(status_item "$ADD_JSON")"
    else
      ADD_STEP="adding to board"
      [ -z "$ON_BOARD" ] || ADD_STEP="reading the board card"
      fail "$ADD_STEP failed${STATUS:+, Status skipped}"
    fi
  fi
  STATUS_OPTION=$(option_id "$STATUS" "${STATUS_OPTIONS:-}")
  if [ -z "$STATUS" ] || [ -z "${ITEM_ID:-}" ]; then
    :
  elif [ -z "${STATUS_FIELD_ID:-}" ] || [ -z "$STATUS_OPTION" ]; then
    note "board has no Status option $STATUS, Status skipped"
  else
    # shellcheck disable=SC2016
    STATUS_QUERY='mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){clientMutationId}}'
    if gh api graphql -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$STATUS_FIELD_ID" -f optionId="$STATUS_OPTION" -f query="$STATUS_QUERY" >/dev/null 2>"$ERR_FILE"; then
      DONE+=("Status $STATUS")
      # Column is where the work is, label who picks it up; these labels contradict the column.
      case "$STATUS" in
        Backlog) CLASH="needs-info status:in-progress" ;;
        Next|Done) CLASH="needs-triage needs-info status:in-progress" ;;
        Doing) CLASH="needs-triage needs-info" ;;
        Blocked) CLASH="status:in-progress" ;;
      esac
    else
      fail "setting Status $STATUS failed"
    fi
  fi
else
  note "no board found on the open issues, board${STATUS:+ and Status} skipped"
fi

if [ -n "$ADD_LABEL$CLASH" ]; then
  DROP=" $CLASH "
  if [ -n "$ADD_LABEL" ]; then
    for pair in $P_LABELS; do DROP="$DROP${pair%%=*} "; done
  fi
  # shortcut: a label added between this read and the write is dropped; a narrow window, use per-label DELETE if it bites.
  REMOVED=() LABEL_ARGS=()
  # Exits 1 unless the full label list was read; a PUT on a partial list would drop labels.
  if OWN_LABELS=$(META_JSON="$META_JSON" python3 -c '
import json, os
labels = ((((json.loads(os.environ["META_JSON"]).get("data") or {}).get("repository") or {}).get("issue") or {}).get("labels") or {})
if (labels.get("pageInfo") or {}).get("hasNextPage") is not False:
    raise SystemExit(1)
for l in labels.get("nodes") or []:
    print(l.get("name"))
' 2>/dev/null); then
    while IFS= read -r l; do
      [ -n "$l" ] && [ "$l" != "$ADD_LABEL" ] || continue
      case "$DROP" in
        *" $l "*) REMOVED+=("$l") ;;
        *) LABEL_ARGS+=(-f "labels[]=$l") ;;
      esac
    done <<<"$OWN_LABELS"
  else
    LEFT="${ADD_LABEL:+any old P label}"
    [ -z "$CLASH" ] || LEFT="${LEFT:+$LEFT and }labels clashing with $STATUS"
    note "could not read all labels, $LEFT left"
  fi
  METHOD=""
  if [ ${#REMOVED[@]} -gt 0 ]; then
    METHOD=PUT
    [ -z "$ADD_LABEL" ] || LABEL_ARGS+=(-f "labels[]=$ADD_LABEL")
    # PUT needs a non-empty list; DELETE clears them all in one write.
    [ ${#LABEL_ARGS[@]} -gt 0 ] || METHOD=DELETE
  elif [ -n "$ADD_LABEL" ]; then
    METHOD=POST LABEL_ARGS=(-f "labels[]=$ADD_LABEL")
  fi
  if [ -z "$METHOD" ]; then
    :
  elif gh api -X "$METHOD" "repos/$OWNER/$NAME/issues/$NUM/labels" ${LABEL_ARGS[@]+"${LABEL_ARGS[@]}"} >/dev/null 2>"$ERR_FILE"; then
    [ -z "$ADD_LABEL" ] || DONE+=("label $ADD_LABEL")
    if [ ${#REMOVED[@]} -gt 0 ]; then
      REMOVED_LIST=$(printf ', %s' "${REMOVED[@]}")
      DONE+=("removed ${REMOVED_LIST#, }")
    fi
  else
    fail "writing labels failed"
  fi
fi

if [ ${#DONE[@]} -gt 0 ]; then
  SUMMARY=$(printf ', %s' "${DONE[@]}")
  echo "issue-meta: #$NUM set ${SUMMARY#, }"
fi
exit 0
