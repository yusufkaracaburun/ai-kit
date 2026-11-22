#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

TMP_IM=$(mktemp -d)
mkdir -p "$TMP_IM/stubs"
cat > "$TMP_IM/stubs/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_DATA/calls.log"
[ -z "${STUB_FAIL:-}" ] || { echo "HTTP 403: Resource not accessible" >&2; echo "second line" >&2; exit 1; }
case "$*" in
  *updateProjectV2ItemFieldValue*) [ -z "${STUB_FAIL_STATUS:-}" ] || { echo "HTTP 403: Resource not accessible" >&2; exit 1; }; echo '{"data":{}}' ;;
  *addProjectV2ItemById*) [ -z "${STUB_FAIL_ADD:-}" ] || { echo "HTTP 403: Resource not accessible" >&2; exit 1; }; cat "$STUB_DATA/add.json" 2>/dev/null || echo '{"data":{}}' ;;
  *setIssueFieldValue*) echo '{"data":{}}' ;;
  *issueTypes*) cat "$STUB_DATA/meta.json" ;;
  *issueFieldValues*) cat "$STUB_DATA/parent.json" ;;
  "api -X PATCH "*|"api -X POST "*|"api -X PUT "*|"api -X DELETE "*) echo '{}' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$TMP_IM/stubs/gh"
(cd "$TMP_IM" && git init -q && git remote add origin git@github.com:acme/demo.git)

write_meta() {
  local types="$1" fields="$2" projects="$3" own="${4:-}" more="${5:-false}" items="${6:-}" boards="${7:-}"
  cat > "$TMP_IM/meta.json" <<JSON
{"data":{"repository":{
  "issueTypes":{"nodes":[$types]},
  "issueFields":{"nodes":[$fields]},
  "issues":{"nodes":[$projects]},
  "issue":{"id":"I_new","labels":{"nodes":[$own],"pageInfo":{"hasNextPage":$more}},"issueFieldValues":{"nodes":[$own]},"projectItems":{"nodes":[$items]},"projectsV2":{"nodes":[$boards]}}}}}
JSON
}
TYPES='{"id":"IT_t","name":"Task"},{"id":"IT_b","name":"Bug"},{"id":"IT_f","name":"Feature"}'
PRIO='{"id":"F_prio","name":"Priority","options":[{"id":"O_u","name":"Urgent"},{"id":"O_h","name":"High"},{"id":"O_m","name":"Medium"},{"id":"O_l","name":"Low"}]},{},{"id":"F_eff","name":"Effort","options":[{"id":"O_eh","name":"High"}]}'
BOARDS='{"projectsV2":{"nodes":[{"id":"PVT_a"}]}},{"projectsV2":{"nodes":[{"id":"PVT_b"}]}},{"projectsV2":{"nodes":[{"id":"PVT_b"},{"id":"PVT_a"}]}},{"projectsV2":{"nodes":[{"id":"PVT_b"}]}}'

RC=0
run_meta() {
  rm -f "$TMP_IM/calls.log"; touch "$TMP_IM/calls.log"
  RC=0
  OUT="$(cd "$TMP_IM" && STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" "$@" 2>&1)" || RC=$?
  CALLS="$(cat "$TMP_IM/calls.log")"
}

echo "=== ai-kit-issue-meta: type, explicit priority, board ==="
write_meta "$TYPES" "$PRIO" "$BOARDS"
run_meta 42 --type Feature --priority High
assert "issue-meta: exit 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: sets issue type via REST" 'echo "$CALLS" | grep -q "api -X PATCH repos/{owner}/{repo}/issues/42 -f type=Feature"'
assert "issue-meta: sets Priority option High" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "fieldId=F_prio" && echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_h"'
assert "issue-meta: adds to board most open issues are on" 'echo "$CALLS" | grep "addProjectV2ItemById" | grep -q "projectId=PVT_b"'
assert "issue-meta: no label when field exists" '! echo "$CALLS" | grep -q "labels\[\]"'
assert "issue-meta: summary joins with comma and space" 'echo "$OUT" | grep -q "#42 set type Feature, Priority High, board$"'

echo ""
echo "=== ai-kit-issue-meta: priority inherited from parent, else Medium ==="
echo '{"data":{"repository":{"issue":{"labels":{"nodes":[]},"issueFieldValues":{"nodes":[{"name":"High","field":{"name":"Effort"}},{"name":"Urgent","field":{"name":"Priority"}}]}}}}}' > "$TMP_IM/parent.json"
run_meta 43 --type Task --parent 40
assert "issue-meta: inherits parent Priority Urgent" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_u"'
assert "issue-meta: parent looked up by number" 'echo "$CALLS" | grep "issueFieldValues" | grep -q "number=40"'

echo '{"data":{"repository":{"issue":{"labels":{"nodes":[]},"issueFieldValues":{"nodes":[]}}}}}' > "$TMP_IM/parent.json"
run_meta 44 --type Task --parent 40
assert "issue-meta: parent without Priority gives Medium" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_m"'

run_meta https://github.com/acme/demo/issues/45 --type Bug
assert "issue-meta: no priority or parent gives Medium" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_m"'
assert "issue-meta: URL resolves owner, repo and number" 'echo "$CALLS" | grep -q "api -X PATCH repos/acme/demo/issues/45 -f type=Bug"'
run_meta https://github.com/acme/demo/issues/55 --type Task --parent 40
assert "issue-meta: bare parent uses the URL issue's repo" 'echo "$CALLS" | grep "number=40" | grep -q "owner=acme -F name=demo"'

echo ""
echo "=== ai-kit-issue-meta: no Priority field falls back to P label ==="
write_meta "$TYPES" "" "$BOARDS"
echo '{"data":{"repository":{"issue":{"labels":{"nodes":[{"name":"P1-high"}]},"issueFieldValues":{"nodes":[]}}}}}' > "$TMP_IM/parent.json"
run_meta 46 --type Task --parent 40
assert "issue-meta: no field exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: no field adds inherited P label" 'echo "$CALLS" | grep -q "api -X POST repos/{owner}/{repo}/issues/46/labels -f labels\[\]=P1-high"'
assert "issue-meta: no field says so" 'echo "$OUT" | grep -q "no Priority field or no High option"'
assert "issue-meta: no field skips setIssueFieldValue" '! echo "$CALLS" | grep -q setIssueFieldValue'

run_meta 47 --type Task --priority Low
assert "issue-meta: no field maps Low to P3-low" 'echo "$CALLS" | grep -q "labels\[\]=P3-low"'

echo ""
echo "=== ai-kit-issue-meta: existing priority is kept unless explicit ==="
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"Low","field":{"name":"Priority"}}'
run_meta 52 --type Bug
assert "issue-meta: existing Priority field kept" '! echo "$CALLS" | grep -q setIssueFieldValue'
run_meta 53 --type Bug --priority High
assert "issue-meta: explicit priority overrides existing" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_h"'
write_meta "$TYPES" "" "$BOARDS" '{"name":"P0-critical"}'
run_meta 54 --type Bug
assert "issue-meta: existing P label kept" '! echo "$CALLS" | grep -q "labels\[\]"'
write_meta "$TYPES" "" "$BOARDS" '{"name":"P0-critical"},{"name":"area-x"}'
run_meta 56 --type Bug --priority Low
assert "issue-meta: new P label replaces the old one" 'echo "$CALLS" | grep "api -X PUT repos/{owner}/{repo}/issues/56/labels" | grep "labels\[\]=area-x" | grep "labels\[\]=P3-low" | grep -vq "P0-critical"'
assert "issue-meta: P label replace is one write" '[ "$(echo "$CALLS" | grep -c "/labels")" -eq 1 ]'
write_meta "$TYPES" "" "$BOARDS" '{"name":"P1-custom"},{"name":"P2-medium"}'
run_meta 59 --type Bug --priority Low
assert "issue-meta: replace keeps a P lookalike, drops the old P label" 'echo "$CALLS" | grep "api -X PUT repos/{owner}/{repo}/issues/59/labels" | grep "labels\[\]=P1-custom" | grep "labels\[\]=P3-low" | grep -vq "P2-medium"'
write_meta "$TYPES" "" "$BOARDS" '{"name":"P1-custom"}'
run_meta 60 --type Bug --priority Low
assert "issue-meta: a P lookalike alone adds, never replaces" '! echo "$CALLS" | grep -q "api -X PUT" && echo "$CALLS" | grep -q "api -X POST repos/{owner}/{repo}/issues/60/labels -f labels\[\]=P3-low$"'
write_meta "$TYPES" "" "$BOARDS" '{"name":"P0-critical"},{"name":"area-x"}' true
run_meta 58 --type Bug --priority Low
assert "issue-meta: more labels than one page adds, never replaces" '! echo "$CALLS" | grep -q "api -X PUT" && echo "$CALLS" | grep -q "api -X POST repos/{owner}/{repo}/issues/58/labels -f labels\[\]=P3-low$" && echo "$OUT" | grep -q "old P label left"'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"P1-high"}'
run_meta 57 --type Bug
assert "issue-meta: P label migrates to the Priority field" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_h"'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"P1"}'
run_meta 61 --type Bug
assert "issue-meta: bare P1 label maps to High" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_h"'

echo ""
echo "=== ai-kit-issue-meta: no types, no board ==="
write_meta "" "$PRIO" '{"projectsV2":{"nodes":[]}}'
run_meta 48 --type Feature
assert "issue-meta: no types or board exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: no types skips type call" '! echo "$CALLS" | grep -q "type=Feature"'
assert "issue-meta: no types says so" 'echo "$OUT" | grep -q "no issue types"'
assert "issue-meta: no board skips add" '! echo "$CALLS" | grep -q addProjectV2ItemById'
assert "issue-meta: no board says so" 'echo "$OUT" | grep -q "no board"'
assert "issue-meta: Priority still set without types or board" 'echo "$CALLS" | grep -q setIssueFieldValue'

echo ""
echo "=== ai-kit-issue-meta: --status moves the card and drops clashing labels ==="
STATUS_FIELD='{"id":"F_st","options":[{"id":"S_bl","name":"Backlog"},{"id":"S_next","name":"Next"},{"id":"S_doing","name":"Doing"},{"id":"S_blocked","name":"Blocked"},{"id":"S_done","name":"Done"}]}'
ITEMS='{"id":"PVTI_other","project":{"id":"PVT_a","field":'"$STATUS_FIELD"'}},{"id":"PVTI_on","project":{"id":"PVT_b","field":'"$STATUS_FIELD"'}}'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"needs-triage"},{"name":"area-x"}' false "$ITEMS"
run_meta 61 --status Next
assert "issue-meta: --status exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: --status sets the option on the derived board's item" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep "projectId=PVT_b" | grep "itemId=PVTI_on" | grep "fieldId=F_st" | grep -q "optionId=S_next"'
assert "issue-meta: move to Next drops needs-triage in one replace" 'echo "$CALLS" | grep "api -X PUT repos/{owner}/{repo}/issues/61/labels" | grep "labels\[\]=area-x" | grep -vq "needs-triage" && [ "$(echo "$CALLS" | grep -c "/labels")" -eq 1 ]'
assert "issue-meta: --status alone sets no type, Priority or board" '! echo "$CALLS" | grep -q "type=\|setIssueFieldValue\|addProjectV2ItemById"'
assert "issue-meta: --status summary" 'echo "$OUT" | grep -q "#61 set Status Next, removed needs-triage$"'

write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"needs-info"}' false "$ITEMS"
run_meta 62 --status Blocked
assert "issue-meta: move to Blocked sets Blocked" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep -q "optionId=S_blocked"'
assert "issue-meta: move to Blocked keeps needs-info" '! echo "$CALLS" | grep -q "/labels"'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"needs-info"}' false "$ITEMS"
run_meta 62 --status Doing
assert "issue-meta: leaving Blocked drops needs-info, the last label, in one delete" 'echo "$CALLS" | grep -q "api -X DELETE repos/{owner}/{repo}/issues/62/labels$" && [ "$(echo "$CALLS" | grep -c "/labels")" -eq 1 ]'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"area-x"}' false "$ITEMS"
run_meta 69 --status Doing
assert "issue-meta: --status Doing alone exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: --status Doing alone writes only Status" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep -q "optionId=S_doing" && ! echo "$CALLS" | grep -q "api -X PATCH\|setIssueFieldValue\|addProjectV2ItemById\|/labels" && [ "$(echo "$CALLS" | wc -l)" -eq 2 ]'
write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"ready-for-human"},{"name":"status:in-progress"}' false "$ITEMS"
run_meta 70 --status Backlog
assert "issue-meta: move to Backlog keeps ready-for-human, drops status:in-progress" 'echo "$CALLS" | grep "api -X PUT repos/{owner}/{repo}/issues/70/labels" | grep "labels\[\]=ready-for-human" | grep -vq "status:in-progress"'

write_meta "$TYPES" "$PRIO" "$BOARDS"
echo '{"data":{"addProjectV2ItemById":{"item":{"id":"PVTI_new","project":{"id":"PVT_b","field":'"$STATUS_FIELD"'}}}}}' > "$TMP_IM/add.json"
run_meta 63 --status Doing
assert "issue-meta: card not on the board yet is added first" 'echo "$CALLS" | grep "addProjectV2ItemById" | grep -q "projectId=PVT_b"'
assert "issue-meta: added card gets its Status" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep "itemId=PVTI_new" | grep -q "optionId=S_doing"'

# GitHub hides a card on a board of another owner (org board, user repo) from issue.projectItems; projectsV2 lists the board.
write_meta "$TYPES" "$PRIO" "$BOARDS" "" false "" '{"id":"PVT_org"}'
echo '{"data":{"addProjectV2ItemById":{"item":{"id":"PVTI_org","project":{"id":"PVT_org","field":'"$STATUS_FIELD"'}}}}}' > "$TMP_IM/add.json"
run_meta 71 --status Done
assert "issue-meta: issue on another owner's board uses that board" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep "projectId=PVT_org" | grep "itemId=PVTI_org" | grep -q "optionId=S_done" && ! echo "$OUT" | grep -q "no board"'
assert "issue-meta: issue already on a board is not reported as added" 'echo "$OUT" | grep -q "#71 set Status Done$"'
write_meta "$TYPES" "$PRIO" '{"projectsV2":{"nodes":[{"id":"PVT_org"}]}}'
run_meta 72 --status Backlog
assert "issue-meta: issue on no board is added to the derived org board" 'echo "$CALLS" | grep "addProjectV2ItemById" | grep -q "projectId=PVT_org" && echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep -q "projectId=PVT_org"'
assert "issue-meta: added issue reports board" 'echo "$OUT" | grep -q "#72 set board, Status Backlog$"'
write_meta "$TYPES" "$PRIO" "$BOARDS" "" false "" '{"id":"PVT_org"}'
RC=0
OUT="$(cd "$TMP_IM" && STUB_FAIL_ADD=1 STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" 73 --status Done 2>&1)" || RC=$?
assert "issue-meta: hidden card lookup failure says reading, not adding" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "reading the board card failed, Status skipped: HTTP 403" && ! echo "$OUT" | grep -q "adding to board"'
write_meta "$TYPES" "$PRIO" "$BOARDS" "" false "$ITEMS" '{"id":"PVT_b"}'
run_meta 74 --status Next
assert "issue-meta: same-owner card is used without an add call" '! echo "$CALLS" | grep -q addProjectV2ItemById && echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep -q "itemId=PVTI_on"'
write_meta "$TYPES" "$PRIO" '{"projectsV2":{"nodes":[null,{"id":"PVT_b"}]}},{"projectsV2":null}' "" false "" 'null'
run_meta 75 --status Next
assert "issue-meta: null board nodes are skipped" 'echo "$CALLS" | grep "addProjectV2ItemById" | grep -q "projectId=PVT_b" && ! echo "$OUT" | grep -q "could not parse"'

write_meta "$TYPES" "" "$BOARDS" '{"name":"needs-triage"},{"name":"area-x"}' false "$ITEMS"
run_meta 64 --type Task --priority Low --status Next
assert "issue-meta: P label and clash removal share one label write" 'echo "$CALLS" | grep "api -X PUT repos/{owner}/{repo}/issues/64/labels" | grep "labels\[\]=area-x" | grep "labels\[\]=P3-low" | grep -vq "needs-triage" && [ "$(echo "$CALLS" | grep -c "/labels")" -eq 1 ]'
assert "issue-meta: card already on board is not re-added" '! echo "$CALLS" | grep -q addProjectV2ItemById'
rm -f "$TMP_IM/add.json"

MULTI_FIELD='{"id":"F_st","options":[{"id":"S_nd","name":"Not Done"},{"id":"S_ip","name":"In Progress"},{"id":"S_done","name":"Done"}]}'
write_meta "$TYPES" "$PRIO" "$BOARDS" "" false '{"id":"PVTI_on","project":{"id":"PVT_b","field":'"$MULTI_FIELD"'}}'
run_meta 67 --status Done
assert "issue-meta: Status Done matches only Done, not Not Done" 'echo "$CALLS" | grep "updateProjectV2ItemFieldValue" | grep -q "optionId=S_done -f query" && [ "$(echo "$CALLS" | grep -c updateProjectV2ItemFieldValue)" -eq 1 ]'
VERY='{"id":"F_prio","name":"Priority","options":[{"id":"O_vh","name":"Very High"},{"id":"O_h","name":"High"}]}'
write_meta "$TYPES" "$VERY" "$BOARDS"
run_meta 68 --type Task --priority High
assert "issue-meta: Priority High matches only High, not Very High" 'echo "$CALLS" | grep "setIssueFieldValue" | grep -q "optionId=O_h -f query"'

write_meta "$TYPES" "$PRIO" '{"projectsV2":{"nodes":[]}}' '{"name":"needs-triage"}'
run_meta 65 --status Next
assert "issue-meta: --status without board exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: --status without board skips status and labels" '! echo "$CALLS" | grep -q "updateProjectV2ItemFieldValue\|/labels" && echo "$OUT" | grep -q "no board.*Status skipped"'

write_meta "$TYPES" "$PRIO" "$BOARDS" '{"name":"needs-triage"}' false "$ITEMS"
RC_ST=0
OUT_ST="$(cd "$TMP_IM" && STUB_FAIL_STATUS=1 STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" 66 --status Next 2>&1)" || RC_ST=$?
assert "issue-meta: Status write failure exits 0" '[ "$RC_ST" -eq 0 ]'
assert "issue-meta: Status failure carries gh's first stderr line" 'echo "$OUT_ST" | grep -q "setting Status Next failed: HTTP 403: Resource not accessible$"'
assert "issue-meta: Status failure leaves labels alone" '! echo "$OUT_ST" | grep -q "removed"'

echo ""
echo "=== ai-kit-issue-meta: API failure and bad args ==="
write_meta "$TYPES" "$PRIO" "$BOARDS"
RC_FAIL=0
OUT_FAIL="$(cd "$TMP_IM" && STUB_FAIL=1 STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" 49 --type Task 2>&1)" || RC_FAIL=$?
assert "issue-meta: API failure exits 0" '[ "$RC_FAIL" -eq 0 ]'
assert "issue-meta: API failure says so" 'echo "$OUT_FAIL" | grep -q "failed"'
assert "issue-meta: failure note carries gh's first stderr line" 'echo "$OUT_FAIL" | grep -q "failed.*: HTTP 403: Resource not accessible$"'

echo "not json" > "$TMP_IM/meta.json"
run_meta 50 --type Task
assert "issue-meta: unparsable reply exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: unparsable reply is not called not found" 'echo "$OUT" | grep -q "could not parse" && ! echo "$OUT" | grep -q "not found"'
write_meta "$TYPES" "$PRIO" "$BOARDS"

mv "$TMP_IM/stubs/gh" "$TMP_IM/gh.ok"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$STUB_DATA/calls.log"\ncase "$*" in *issueTypes*) cat "$STUB_DATA/meta.json" ;; *) exit 1 ;; esac\n' > "$TMP_IM/stubs/gh"
chmod +x "$TMP_IM/stubs/gh"
run_meta 51 --type Feature --priority High
assert "issue-meta: write failures exit 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: each failed write is reported" '[ "$(echo "$OUT" | grep -c "failed")" -eq 3 ]'
mv "$TMP_IM/gh.ok" "$TMP_IM/stubs/gh"

rm -f "$TMP_IM/calls.log"
for bad in "" "--type Task" "42" "42 --type Epic" "42 --type Task --priority P1" "42 --type Task --bogus" \
  "https://github.com/ac\$me/demo/issues/1 --type Task" "https://github.com/acme/demo/issues/45abc --type Task" \
  "42 --status Doing2" "42 --priority High" "42 --status Next --parent 40"; do
  RC_BAD=0
  # shellcheck disable=SC2086
  (cd "$TMP_IM" && STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" $bad >/dev/null 2>&1) || RC_BAD=$?
  assert "issue-meta: bad args '$bad' exit 2" '[ "$RC_BAD" -eq 2 ]'
done
assert "issue-meta: bad args make no gh call" '[ ! -s "$TMP_IM/calls.log" ]'

rm -rf "$TMP_IM"
print_summary_and_exit
