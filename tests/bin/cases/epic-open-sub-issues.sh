#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

SCRIPT="$AIKIT/workflow/context/templates/github/scripts/epic-open-sub-issues.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stubs"
cat > "$T/stubs/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "api repos/acme/demo/issues/7 --jq .type.name // \"\"") cat "$STUB/type" ;;
  "api --paginate repos/acme/demo/issues/7/sub_issues") cat "$STUB/subs.json" ;;
  "issue comment 7 -R acme/demo -b "*) printf '%s' "${*#issue comment 7 -R acme/demo -b }" > "$STUB/reopened" ;;
  "issue reopen 7 -R acme/demo") touch "$STUB/reopen-called" ;;
  # real gh skips -c on an issue that is already open
  "issue reopen 7 -R acme/demo -c "*) [ -f "$STUB/already-open" ] || printf '%s' "${*#issue reopen 7 -R acme/demo -c }" > "$STUB/reopened" ;;
  *) echo "unexpected: $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$T/stubs/gh"

sub() { printf '{"number":%s,"title":"%s","state":"%s","labels":[%s]}' "$1" "$2" "$3" "${4:-}"; }
run() {
  rm -f "$T/reopened" "$T/reopen-called"
  RC=0
  OUT="$(STUB="$T" REPO=acme/demo ISSUE=7 PATH="$T/stubs:$PATH" bash "$SCRIPT" 2>&1)" || RC=$?
}

echo "=== epic-open-sub-issues: reopen when an open sub-issue lacks the later label ==="
echo Epic > "$T/type"
echo "[$(sub 11 "Login form" open),$(sub 12 "Import" open '{"name":"na-migratie"}'),$(sub 13 "Done one" closed)]" > "$T/subs.json"
run
assert "epic reopened" '[ -f "$T/reopen-called" ]'
assert "comment lists the open sub-issue without the later label" 'grep -q "#11 Login form" "$T/reopened"'
assert "comment skips the later-labelled and closed ones" '! grep -q "#12\|#13" "$T/reopened"'
assert "comment says board Status is not shown" 'grep -q "Status" "$T/reopened"'
assert "reopen fails the job" '[ "$RC" -eq 1 ]'

touch "$T/already-open"
run
rm "$T/already-open"
assert "epic already reopened by the enforce job: list still posted" 'grep -q "#11 Login form" "$T/reopened"'

echo "[$(sub 11 "Login form" open '{"name":"later"}')]" > "$T/subs.json"
LATER_LABEL=later run
assert "LATER_LABEL overrides the default label" '[ ! -f "$T/reopened" ] && [ "$RC" -eq 0 ]'

echo "=== epic-open-sub-issues: no reopen ==="
echo "[$(sub 12 "Import" open '{"name":"na-migratie"}'),$(sub 13 "Done one" closed)]" > "$T/subs.json"
run
assert "all open sub-issues carry the later label: no reopen" '[ ! -f "$T/reopened" ] && [ "$RC" -eq 0 ]'
echo "[$(sub 13 "Done one" closed)]" > "$T/subs.json"
run
assert "no open sub-issues: no reopen" '[ ! -f "$T/reopened" ] && [ "$RC" -eq 0 ]'
echo "[$(sub 11 "Login form" open)]" > "$T/subs.json"
echo Task > "$T/type"
run
assert "not an epic: no reopen" '[ ! -f "$T/reopened" ] && [ "$RC" -eq 0 ]'
echo Feature > "$T/type"
run
assert "Feature counts as an epic" '[ -f "$T/reopened" ]'

print_summary_and_exit
