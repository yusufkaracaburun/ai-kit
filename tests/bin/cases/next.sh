#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== ai-kit-next: help + empty repo ==="
OUT_HELP="$("$AIKIT/bin/ai-kit-next.sh" --help 2>&1)"
assert "next: help mentions sources" 'echo "$OUT_HELP" | grep -q "gh issue list"'
assert "next: help mentions --limit" 'echo "$OUT_HELP" | grep -q -- "--limit"'

# Empty dir — no GH remote, no roadmap, no marker.
TMP_EMPTY=$(mktemp -d)
OUT_EMPTY="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_EMPTY" --no-gh 2>&1)"
assert "next: empty repo says nothing open" 'echo "$OUT_EMPTY" | grep -q "nothing open"'
rm -rf "$TMP_EMPTY"

echo ""
echo "=== ai-kit-next: roadmap parsing ==="
TMP_RM=$(mktemp -d)
mkdir -p "$TMP_RM/docs"
cat > "$TMP_RM/docs/roadmap.md" <<'EOF'
# Roadmap

## 1. Section header (must be ignored)

> Block quote bullet should also be ignored.

**Bold prose** with - dashes in it.

- This is a free bullet — must NOT count as a task.
- [x] Closed task — must NOT count.
- [ ] OPEN TASK ONE — should count (P1).
- [ ] Open task two without priority hint.
- [ ] Refers to existing GH #999 — should be deduped against gh list.

```
- [ ] Inside code fence — must NOT count.
```

- [ ] After code fence — should count.
EOF
OUT_RM="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_RM" --no-gh --json 2>&1)"
ROADMAP_COUNT="$(echo "$OUT_RM" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for x in d['items'] if x['kind']=='roadmap'))")"
assert "next: counts exactly 4 open roadmap tasks (skips closed + prose + code + fence)" '[ "$ROADMAP_COUNT" -eq 4 ]'
assert "next: picks up P-hint from task" 'echo "$OUT_RM" | grep -q "\"priority\": \"P1\""'
assert "next: open task one surfaced" 'echo "$OUT_RM" | grep -q "OPEN TASK ONE"'
assert "next: closed task suppressed" '! echo "$OUT_RM" | grep -q "Closed task"'
assert "next: free bullet suppressed" '! echo "$OUT_RM" | grep -q "free bullet"'
rm -rf "$TMP_RM"

echo ""
echo "=== ai-kit-next: setup-marker deferred branches ==="
TMP_MK=$(mktemp -d)
cat > "$TMP_MK/.ai-kit-setup" <<'JSON'
{
  "ai_kit_version": "3.1.0",
  "branches": {
    "setup_mode": "solo-both",
    "automation_recommender": "deferred",
    "rule_recommendation": "deferred",
    "architecture": "documented"
  }
}
JSON
OUT_MK="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_MK" --no-gh --json 2>&1)"
DEFERRED_COUNT="$(echo "$OUT_MK" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for x in d['items'] if x['kind']=='deferred'))")"
assert "next: 2 deferred branches surfaced" '[ "$DEFERRED_COUNT" -eq 2 ]'
assert "next: automation_recommender surfaced" 'echo "$OUT_MK" | grep -q "automation_recommender"'
assert "next: documented branch NOT surfaced" '! echo "$OUT_MK" | grep -q "Setup branch: architecture"'
rm -rf "$TMP_MK"

echo ""
echo "=== ai-kit-next: GH JSON scoring (stubbed) ==="
TMP_GH=$(mktemp -d)
mkdir -p "$TMP_GH/stubs"
cat > "$TMP_GH/stubs/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh CLI returning two issues with different priorities + flags.
cat <<'JSON'
[
  {"number": 1, "title": "Critical bug", "labels": [{"name":"P0-critical"},{"name":"status:in-progress"}], "updatedAt": "2026-05-23T10:00:00Z", "url": "https://github.com/x/y/issues/1", "assignees": []},
  {"number": 2, "title": "Nice to have", "labels": [{"name":"P3-low"}], "updatedAt": "2026-05-20T10:00:00Z", "url": "https://github.com/x/y/issues/2", "assignees": []},
  {"number": 3, "title": "Queue ready", "labels": [{"name":"P2-medium"},{"name":"ready-for-agent"}], "updatedAt": "2026-05-22T10:00:00Z", "url": "https://github.com/x/y/issues/3", "assignees": []}
]
JSON
STUB
chmod +x "$TMP_GH/stubs/gh"
# Init a git repo so the ranker recognises the dir as a git working tree.
(cd "$TMP_GH" && git init -q && git remote add origin git@github.com:x/y.git)
OUT_GH="$(PATH="$TMP_GH/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_GH" --no-roadmap 2>&1)"
assert "next: P0 in-progress ranks first" 'echo "$OUT_GH" | grep -A1 "^   1\." | grep -q "Critical bug"'
assert "next: P2 ready-for-agent ranks second" 'echo "$OUT_GH" | grep -A1 "^   2\." | grep -q "Queue ready"'
assert "next: P3 ranks last" 'echo "$OUT_GH" | grep -A1 "^   3\." | grep -q "Nice to have"'
rm -rf "$TMP_GH"

echo ""
echo "=== ai-kit-next: Priority issue field + project Status (stubbed) ==="
TMP_PF=$(mktemp -d)
mkdir -p "$TMP_PF/stubs"
cat > "$TMP_PF/stubs/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "issue list") cat "$STUB_DATA/issues.json" ;;
  "api graphql")
    case "$*" in *projectItems*) [ -z "${STUB_STATUS_FAIL:-}" ] || exit 1 ;; esac
    [ -f "$STUB_DATA/graphql.json" ] || exit 1; cat "$STUB_DATA/graphql.json" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$TMP_PF/stubs/gh"
(cd "$TMP_PF" && git init -q && git remote add origin git@github.com:acme/demo.git)
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$TMP_PF/issues.json" <<JSON
[
  {"number": 10, "title": "Field wins", "labels": [{"name":"P3-low"}], "updatedAt": "$NOW", "url": "u10", "assignees": []},
  {"number": 11, "title": "Label fallback", "labels": [{"name":"P0-critical"}], "updatedAt": "$NOW", "url": "u11", "assignees": []},
  {"number": 12, "title": "Doing twice", "labels": [{"name":"P2-medium"},{"name":"status:in-progress"}], "updatedAt": "$NOW", "url": "u12", "assignees": []},
  {"number": 13, "title": "Next only", "labels": [], "updatedAt": "$NOW", "url": "u13", "assignees": []},
  {"number": 14, "title": "Next twice", "labels": [{"name":"ready-for-agent"}], "updatedAt": "$NOW", "url": "u14", "assignees": []},
  {"number": 15, "title": "Blocked item", "labels": [{"name":"P0-critical"}], "updatedAt": "$NOW", "url": "u15", "assignees": []},
  {"number": 16, "title": "Done item", "labels": [], "updatedAt": "$NOW", "url": "u16", "assignees": []},
  {"number": 17, "title": "Doing field", "labels": [{"name":"P2-medium"}], "updatedAt": "$NOW", "url": "u17", "assignees": []},
  {"number": 18, "title": "Doing untriaged", "labels": [{"name":"needs-triage"}], "updatedAt": "$NOW", "url": "u18", "assignees": []},
  {"number": 19, "title": "Blocked plain", "labels": [], "updatedAt": "$NOW", "url": "u19", "assignees": []}
]
JSON
cat > "$TMP_PF/graphql.json" <<'JSON'
{"data": {"repository": {"issues": {"nodes": [
  {"number": 10, "issueFieldValues": {"nodes": [{"name": "High", "field": {"name": "Priority"}}]}, "projectItems": {"nodes": [{"status": {"name": "Backlog"}}]}},
  {"number": 11, "issueFieldValues": {"nodes": [{"name": "High", "field": {"name": "Effort"}}]}, "projectItems": {"nodes": []}},
  {"number": 12, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Doing"}}]}},
  {"number": 13, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Next"}}]}},
  {"number": 14, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Next"}}]}},
  {"number": 15, "issueFieldValues": {"nodes": [{"name": "Urgent", "field": {"name": "Priority"}}]}, "projectItems": {"nodes": [{"status": {"name": "Blocked"}}]}},
  {"number": 16, "issueFieldValues": {"nodes": [{"name": "Low", "field": {"name": "Priority"}}]}, "projectItems": {"nodes": [{"status": {"name": "Done"}}]}},
  {"number": 17, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Doing"}}]}},
  {"number": 18, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Doing"}}]}},
  {"number": 19, "issueFieldValues": {"nodes": []}, "projectItems": {"nodes": [{"status": {"name": "Blocked"}}]}}
]}}}}
JSON
pf_field() {
  echo "$1" | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((str(x['$3']) for x in d['items'] if x.get('number')==$2), 'absent'))"
}
OUT_PF="$(STUB_DATA="$TMP_PF" PATH="$TMP_PF/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_PF" --no-roadmap --json 2>&1)"
assert "next: Priority issue field High beats P3 label" '[ "$(pf_field "$OUT_PF" 10 priority)" = "P1" ] && [ "$(pf_field "$OUT_PF" 10 score)" -eq 100 ]'
assert "next: no Priority issue field falls back to P0 label" '[ "$(pf_field "$OUT_PF" 11 priority)" = "P0" ]'
assert "next: Status Doing + in-progress label counts +50 once" '[ "$(pf_field "$OUT_PF" 12 score)" -eq 60 ]'
assert "next: Status Doing alone gives +50" '[ "$(pf_field "$OUT_PF" 17 score)" -eq 60 ] && [ "$(pf_field "$OUT_PF" 17 status_in_progress)" = "True" ]'
assert "next: Status Next gives +20" '[ "$(pf_field "$OUT_PF" 13 score)" -eq 25 ]'
assert "next: Status Next + ready-for-agent label counts +20 once" '[ "$(pf_field "$OUT_PF" 14 score)" -eq 25 ]'
assert "next: Status Blocked item absent" '[ "$(pf_field "$OUT_PF" 15 number)" = "absent" ]'
assert "next: Status Done item absent" '[ "$(pf_field "$OUT_PF" 16 number)" = "absent" ]'

OUT_PF_TEXT="$(STUB_DATA="$TMP_PF" PATH="$TMP_PF/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_PF" --no-roadmap 2>&1)"
assert "next: Doing with needs-triage warns once" '[ "$(echo "$OUT_PF_TEXT" | grep -c "warning: #18 is in Doing but labelled needs-triage")" -eq 1 ]'
assert "next: clean cards and plain Blocked do not warn" '[ "$(echo "$OUT_PF_TEXT" | grep -c "warning:")" -eq 1 ]'
assert "next: clash warning does not change ranking" '[ "$(pf_field "$OUT_PF" 18 score)" -eq 55 ]'

OUT_PF_STATUS="$(STUB_STATUS_FAIL=1 STUB_DATA="$TMP_PF" PATH="$TMP_PF/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_PF" --no-roadmap --json 2>&1)"
assert "next: Status query failure keeps Priority field ranking" '[ "$(pf_field "$OUT_PF_STATUS" 10 priority)" = "P1" ] && [ "$(pf_field "$OUT_PF_STATUS" 15 priority)" = "P0" ]'

rm "$TMP_PF/graphql.json"
RC_PF=0
OUT_PF_FAIL="$(STUB_DATA="$TMP_PF" PATH="$TMP_PF/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_PF" --no-roadmap --json 2>&1)" || RC_PF=$?
assert "next: GraphQL failure exits 0" '[ "$RC_PF" -eq 0 ]'
assert "next: GraphQL failure ranks by label only" '[ "$(pf_field "$OUT_PF_FAIL" 10 priority)" = "P3" ] && [ "$(pf_field "$OUT_PF_FAIL" 15 priority)" = "P0" ]'
rm -rf "$TMP_PF"

print_summary_and_exit
