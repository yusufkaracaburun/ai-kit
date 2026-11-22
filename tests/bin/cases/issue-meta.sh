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
  *setIssueFieldValue*|*addProjectV2ItemById*) echo '{"data":{}}' ;;
  *issueTypes*) cat "$STUB_DATA/meta.json" ;;
  *issueFieldValues*) cat "$STUB_DATA/parent.json" ;;
  "api -X PATCH "*|"api -X POST "*|"api -X PUT "*) echo '{}' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$TMP_IM/stubs/gh"
(cd "$TMP_IM" && git init -q && git remote add origin git@github.com:acme/demo.git)

write_meta() {
  local types="$1" fields="$2" projects="$3" own="${4:-}" more="${5:-false}"
  cat > "$TMP_IM/meta.json" <<JSON
{"data":{"repository":{
  "issueTypes":{"nodes":[$types]},
  "issueFields":{"nodes":[$fields]},
  "issues":{"nodes":[$projects]},
  "issue":{"id":"I_new","labels":{"nodes":[$own],"pageInfo":{"hasNextPage":$more}},"issueFieldValues":{"nodes":[$own]}}}}}
JSON
}
TYPES='{"id":"IT_t","name":"Task"},{"id":"IT_b","name":"Bug"},{"id":"IT_f","name":"Feature"}'
PRIO='{"id":"F_prio","name":"Priority","options":[{"id":"O_u","name":"Urgent"},{"id":"O_h","name":"High"},{"id":"O_m","name":"Medium"},{"id":"O_l","name":"Low"}]},{},{"id":"F_eff","name":"Effort","options":[{"id":"O_eh","name":"High"}]}'
BOARDS='{"projectItems":{"nodes":[{"project":{"id":"PVT_a"}}]}},{"projectItems":{"nodes":[{"project":{"id":"PVT_b"}}]}},{"projectItems":{"nodes":[{"project":{"id":"PVT_b"}},{"project":{"id":"PVT_a"}}]}},{"projectItems":{"nodes":[{"project":{"id":"PVT_b"}}]}}'

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

echo ""
echo "=== ai-kit-issue-meta: no types, no board ==="
write_meta "" "$PRIO" '{"projectItems":{"nodes":[]}}'
run_meta 48 --type Feature
assert "issue-meta: no types or board exits 0" '[ "$RC" -eq 0 ]'
assert "issue-meta: no types skips type call" '! echo "$CALLS" | grep -q "type=Feature"'
assert "issue-meta: no types says so" 'echo "$OUT" | grep -q "no issue types"'
assert "issue-meta: no board skips add" '! echo "$CALLS" | grep -q addProjectV2ItemById'
assert "issue-meta: no board says so" 'echo "$OUT" | grep -q "no board"'
assert "issue-meta: Priority still set without types or board" 'echo "$CALLS" | grep -q setIssueFieldValue'

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
  "https://github.com/ac\$me/demo/issues/1 --type Task" "https://github.com/acme/demo/issues/45abc --type Task"; do
  RC_BAD=0
  # shellcheck disable=SC2086
  (cd "$TMP_IM" && STUB_DATA="$TMP_IM" PATH="$TMP_IM/stubs:$PATH" "$AIKIT/bin/ai-kit-issue-meta.sh" $bad >/dev/null 2>&1) || RC_BAD=$?
  assert "issue-meta: bad args '$bad' exit 2" '[ "$RC_BAD" -eq 2 ]'
done
assert "issue-meta: bad args make no gh call" '[ ! -s "$TMP_IM/calls.log" ]'

rm -rf "$TMP_IM"
print_summary_and_exit
