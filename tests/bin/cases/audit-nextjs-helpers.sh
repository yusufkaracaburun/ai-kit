#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# audit-nextjs-helpers.sh's own subcommands (detect_router, run_tools), not
# the full audit-architecture-nextjs extension bundle (SKILL.md, loader
# match, contract) — that plumbing is already covered via the react
# sibling's test; this file exists because THIS helper's router-detection
# logic was the one branch with zero coverage.
#
# NOT COVERED: the tool-present (✓) path of run_tools — it would need a fake
# `next` binary on PATH. The react sibling test only covers the ✗-gate path
# too, so this stays consistent with that precedent.

HELPER="$AIKIT/bin/audit-nextjs-helpers.sh"

echo "=== detect_router ==="
T=$(mktemp -d)
mkdir -p "$T/app"
assert "app/ only -> app" '[ "$("$HELPER" detect_router "$T")" = "app" ]'
rm -rf "$T/app"

mkdir -p "$T/pages"
assert "pages/ only -> pages" '[ "$("$HELPER" detect_router "$T")" = "pages" ]'

mkdir -p "$T/app"
assert "app/ + pages/ -> both" '[ "$("$HELPER" detect_router "$T")" = "both" ]'
rm -rf "$T/app" "$T/pages"

assert "neither -> none" '[ "$("$HELPER" detect_router "$T")" = "none" ]'

mkdir -p "$T/src/app"
assert "src/app/ -> app (src-prefixed variant)" '[ "$("$HELPER" detect_router "$T")" = "app" ]'
rm -rf "$T"

echo "=== run_tools ==="
T=$(mktemp -d)
OUT=$(PATH=/usr/bin:/bin "$HELPER" run_tools "$T")
assert "next binary absent -> gated ✗" 'grep -qE "next lint ✗" <<<"$OUT"'
assert "still emits a cache line" 'grep -q "Cache:" <<<"$OUT"'
rm -rf "$T"

echo "=== usage / arg handling ==="
RC=0; "$HELPER" 2>/dev/null || RC=$?
assert "no args -> usage, exit 2" '[ "$RC" -eq 2 ]'

T=$(mktemp -d)
RC=0; "$HELPER" bogus_sub "$T" >/dev/null 2>&1 || RC=$?
assert "unknown subcommand -> usage, exit 2" '[ "$RC" -eq 2 ]'
rm -rf "$T"

print_summary_and_exit
