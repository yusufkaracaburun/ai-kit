#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

LEAN="$AIKIT/bin/ai-kit-context-lean.sh"
HYG="$AIKIT/bin/ai-kit-hygiene.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-context-lean.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "=== ai-kit-context-lean: always-loaded file size ==="
# section: ai-kit-context-lean

# No CLAUDE.md / AGENTS.md at root → silent skip, exit 0.
mkdir -p "$TMP/empty"
OUT_EMPTY="$("$LEAN" "$TMP/empty" 2>&1)"; RC_EMPTY=$?
assert "context-lean exits 0 when no root CLAUDE.md/AGENTS.md" '[ "$RC_EMPTY" -eq 0 ]'
assert "context-lean reports skip when no files" 'echo "$OUT_EMPTY" | grep -q "skipped"'

# Small CLAUDE.md (under 200 lines) → clean, exit 0.
mkdir -p "$TMP/small"
seq 1 50 | sed 's/^/line /' > "$TMP/small/CLAUDE.md"
OUT_SMALL="$("$LEAN" "$TMP/small" 2>&1)"; RC_SMALL=$?
assert "context-lean exits 0 on 50-line CLAUDE.md" '[ "$RC_SMALL" -eq 0 ]'
assert "context-lean prints ok line with count" 'echo "$OUT_SMALL" | grep -q "ok: CLAUDE.md — 50 lines"'

# Bloated CLAUDE.md (over 200 lines) → warn, exit 1, fix hint present.
mkdir -p "$TMP/bloated"
seq 1 210 | sed 's/^/line /' > "$TMP/bloated/CLAUDE.md"
OUT_BLOAT="$("$LEAN" "$TMP/bloated" 2>&1)" && RC_BLOAT=0 || RC_BLOAT=$?
assert "context-lean exits 1 on 210-line CLAUDE.md" '[ "$RC_BLOAT" -eq 1 ]'
assert "context-lean warns with line count" 'echo "$OUT_BLOAT" | grep -q "WARN: CLAUDE.md is 210 lines"'
assert "context-lean suggests path-scoped split" 'echo "$OUT_BLOAT" | grep -q "path-scoped rules"'

# Bloated AGENTS.md also triggers the warn.
mkdir -p "$TMP/agents"
seq 1 250 | sed 's/^/line /' > "$TMP/agents/AGENTS.md"
OUT_AGENTS="$("$LEAN" "$TMP/agents" 2>&1)" && RC_AGENTS=0 || RC_AGENTS=$?
assert "context-lean exits 1 on 250-line AGENTS.md" '[ "$RC_AGENTS" -eq 1 ]'
assert "context-lean warns on AGENTS.md" 'echo "$OUT_AGENTS" | grep -q "WARN: AGENTS.md is 250 lines"'

# Boost-managed AGENTS.md (wholesale <laravel-boost-guidelines> block) is
# skipped with a note, never warned — its size is Boost's call.
mkdir -p "$TMP/boost"
{ echo "<laravel-boost-guidelines>"; seq 1 250 | sed 's/^/line /'; echo "</laravel-boost-guidelines>"; } > "$TMP/boost/AGENTS.md"
OUT_BOOST="$("$LEAN" "$TMP/boost" 2>&1)"; RC_BOOST=$?
assert "context-lean exits 0 on Boost-managed 252-line AGENTS.md" '[ "$RC_BOOST" -eq 0 ]'
assert "context-lean notes Boost-managed skip" 'echo "$OUT_BOOST" | grep -q "Boost-managed"'

# A Boost block appended below hand-authored content (Boost's default
# CLAUDE.md target, not a dedicated AGENTS.md) excludes only the generated
# lines from the count — the authored part still gets curated.
mkdir -p "$TMP/boost-appended-small"
{ seq 1 50 | sed 's/^/line /'; echo "<laravel-boost-guidelines>"; seq 1 300 | sed 's/^/line /'; echo "</laravel-boost-guidelines>"; } > "$TMP/boost-appended-small/CLAUDE.md"
OUT_BOOST_SMALL="$("$LEAN" "$TMP/boost-appended-small" 2>&1)"; RC_BOOST_SMALL=$?
assert "context-lean excludes appended Boost block from the count" '[ "$RC_BOOST_SMALL" -eq 0 ]'
assert "context-lean reports the 50-line authored count, not the 351-line total" 'echo "$OUT_BOOST_SMALL" | grep -q "ok: CLAUDE.md — 50 lines"'
assert "context-lean notes the excluded block" 'echo "$OUT_BOOST_SMALL" | grep -q "Boost-managed block from line 51"'

mkdir -p "$TMP/boost-appended-bloated"
{ seq 1 210 | sed 's/^/line /'; echo "<laravel-boost-guidelines>"; seq 1 300 | sed 's/^/line /'; echo "</laravel-boost-guidelines>"; } > "$TMP/boost-appended-bloated/CLAUDE.md"
OUT_BOOST_BLOAT="$("$LEAN" "$TMP/boost-appended-bloated" 2>&1)" && RC_BOOST_BLOAT=0 || RC_BOOST_BLOAT=$?
assert "context-lean still warns when the authored part alone is over 200" '[ "$RC_BOOST_BLOAT" -eq 1 ]'
assert "context-lean warns with the authored count, not the inflated total" 'echo "$OUT_BOOST_BLOAT" | grep -q "WARN: CLAUDE.md is 210 lines"'

# Exactly 200 lines is still clean (threshold is "over", not "at").
mkdir -p "$TMP/edge"
seq 1 200 | sed 's/^/line /' > "$TMP/edge/CLAUDE.md"
OUT_EDGE="$("$LEAN" "$TMP/edge" 2>&1)"; RC_EDGE=$?
assert "context-lean exits 0 on exactly 200 lines" '[ "$RC_EDGE" -eq 0 ]'

echo ""
echo "=== hygiene integration: context-lean section ==="
# section: ai-kit-hygiene-context-lean

# Bloated project, all other sections skipped → warning costs 5 points.
OUT_HYG="$("$HYG" "$TMP/bloated" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills 2>&1)" || true
assert "hygiene runs context-lean section" 'echo "$OUT_HYG" | grep -q "=== context-lean"'
assert "hygiene scores 95 with only context-lean warning" 'echo "$OUT_HYG" | grep -q "^Score: 95/100$"'
assert "hygiene recipe names context-lean" 'echo "$OUT_HYG" | grep -q "resolve warning in context-lean"'

# --skip-context-lean suppresses the section.
OUT_SKIP="$("$HYG" "$TMP/bloated" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean 2>&1)"
assert "hygiene honours --skip-context-lean" '! echo "$OUT_SKIP" | grep -q "=== context-lean"'
assert "hygiene scores 100 when context-lean skipped" 'echo "$OUT_SKIP" | grep -q "^Score: 100/100$"'


echo ""
echo "=== ai-kit-context-lean: pathless .claude/rules are a native always-on tax (#182) ==="
# section: ai-kit-context-lean-native-rules
# Claude Code loads every pathless .claude/rules/*.md at session start; a
# rule with paths: loads on touch. This reconciles that with the CLAUDE.md
# ceiling instead of leaving it invisible to /ai:hygiene.
mkdir -p "$TMP/rules-ok"
"$AIKIT/bin/emit-rules.sh" "$TMP/rules-ok" --rules secrets-hygiene,laravel-conventions --agents claude-code >/dev/null
OUT_RULES_OK="$("$LEAN" "$TMP/rules-ok" 2>&1)"; RC_RULES_OK=$?
assert "context-lean exits 0 on an in-budget rule set" '[ "$RC_RULES_OK" -eq 0 ]'
assert "context-lean reports the universal pathless rule as a note, not a score" \
  'echo "$OUT_RULES_OK" | grep -q "^note: 1 universal ai-kit rule(s)"'
assert "context-lean does not count the scoped rule" \
  '! echo "$OUT_RULES_OK" | grep -q "laravel-conventions"'

mkdir -p "$TMP/rules-default"
"$AIKIT/bin/emit-rules.sh" "$TMP/rules-default" --agents claude-code >/dev/null
OUT_RULES_DEFAULT="$("$LEAN" "$TMP/rules-default" 2>&1)"; RC_RULES_DEFAULT=$?
assert "context-lean exits 0 on the kit's own default universal set" '[ "$RC_RULES_DEFAULT" -eq 0 ]'

mkdir -p "$TMP/rules-over/.claude/rules"
for i in 1 2 3 4 5 6; do printf '# Local rule %s\n\n%s\n' "$i" "$(yes word | head -400 | tr '\n' ' ')" > "$TMP/rules-over/.claude/rules/local-$i.md"; done
OUT_RULES_OVER="$("$LEAN" "$TMP/rules-over" 2>&1)" && RC_RULES_OVER=0 || RC_RULES_OVER=$?
assert "context-lean exits 1 when pathless non-universal rules exceed the budget" '[ "$RC_RULES_OVER" -eq 1 ]'
assert "context-lean warns with the pathless word count" \
  'echo "$OUT_RULES_OVER" | grep -q "^WARN: 6 pathless non-universal rule(s) in .claude/rules"'
assert "context-lean fix-hint names paths:" \
  'echo "$OUT_RULES_OVER" | grep -q "give the rule \`paths:\`"'

print_summary_and_exit
