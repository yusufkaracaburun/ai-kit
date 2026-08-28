#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== secrets-gate (hygiene section) ==="
# The section grades wiring, never history. A history scan takes tens of
# seconds and returns the same answer until somebody commits, so running it
# per hygiene call would end hygiene's usability and re-derive an unchanged
# result. A missing gate is a warning worth five points — never a blocker,
# which in this score model means the install is broken.

GATE="$AIKIT/bin/ai-kit-secrets-gate.sh"
HYG="$AIKIT/bin/ai-kit-hygiene.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=./secrets-gate.sh
source "$AIKIT/tests/bin/cases/secrets-gate.sh"

wire_ci() {
  mkdir -p "$1/.github/workflows"
  printf 'name: gitleaks\njobs:\n  scan:\n    runs-on: ubuntu-latest\n' > "$1/.github/workflows/gitleaks.yml"
}

# --- fully wired: CI plus a guard in an existing husky hook
WIRED="$(new_repo wired)"
wire_ci "$WIRED"
mkdir -p "$WIRED/.husky"
printf '#!/bin/sh\nnpx lint-staged\ngitleaks protect --staged\n' > "$WIRED/.husky/pre-commit"
git -C "$WIRED" config core.hooksPath .husky/_

# --- CI only, and no pre-commit mechanism to extend. Must not be marked
# --- down for a half it cannot have.
CIONLY="$(new_repo ci-only)"
wire_ci "$CIONLY"

# --- mechanism present but carrying no guard
UNGUARDED="$(new_repo unguarded)"
wire_ci "$UNGUARDED"
mkdir -p "$UNGUARDED/.husky"
printf '#!/bin/sh\nnpx lint-staged\n' > "$UNGUARDED/.husky/pre-commit"
git -C "$UNGUARDED" config core.hooksPath .husky/_

# --- nothing wired at all
BARE="$(new_repo bare)"

"$GATE" "$WIRED"     >"$TMP/o.wired" 2>&1 && RC_WIRED=0    || RC_WIRED=$?
"$GATE" "$CIONLY"    >"$TMP/o.cionly" 2>&1 && RC_CIONLY=0  || RC_CIONLY=$?
"$GATE" "$UNGUARDED" >"$TMP/o.ung" 2>&1 && RC_UNG=0        || RC_UNG=$?
"$GATE" "$BARE"      >"$TMP/o.bare" 2>&1 && RC_BARE=0      || RC_BARE=$?

assert "fully wired is clean" '[ "$RC_WIRED" -eq 0 ]'
assert "CI-only with no mechanism is clean" '[ "$RC_CIONLY" -eq 0 ]'
assert "CI-only says why it is not penalised" 'grep -q "no pre-commit mechanism to extend" "$TMP/o.cionly"'
assert "mechanism without a guard warns" '[ "$RC_UNG" -eq 1 ]'
assert "nothing wired warns" '[ "$RC_BARE" -eq 1 ]'
assert "the fix names the applier" 'grep -q "apply-secrets-gate.sh" "$TMP/o.bare"'

# It grades wiring. If it ever shells out to a scan, a large repo turns a
# millisecond check into a minute one. Asserted by behaviour rather than by
# grepping the source: the script legitimately mentions both names in its
# remedy text, so a source grep answers the wrong question.
STUB="$TMP/stub"
mkdir -p "$STUB"
printf '#!/bin/sh\ntouch "%s/gitleaks-ran"\nexit 0\n' "$TMP" > "$STUB/gitleaks"
chmod +x "$STUB/gitleaks"
PATH="$STUB:$PATH" "$GATE" "$UNGUARDED" >/dev/null 2>&1 || true
assert "section never executes gitleaks" '[ ! -e "$TMP/gitleaks-ran" ]'

# Blocker weight is reserved for a broken install. No input may produce one.
mkdir -p "$TMP/notgit"
"$GATE" "$TMP/notgit" >"$TMP/o.notgit" 2>&1 && RC_NG=0 || RC_NG=$?
assert "a non-git directory is skipped, not blocked" '[ "$RC_NG" -eq 0 ]'
"$GATE" "$TMP/does-not-exist" >/dev/null 2>&1 && RC_MISSING=0 || RC_MISSING=$?
assert "a missing directory never blocks" '[ "$RC_MISSING" -le 1 ]'

echo ""
echo "=== hygiene integration ==="
# Every other section skipped, so the score isolates this one: one warning
# costs exactly five points.
OUT_WARN="$("$HYG" "$BARE" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean 2>&1)" || true
assert "hygiene runs the secrets-gate section" 'echo "$OUT_WARN" | grep -q "=== secrets-gate"'
assert "one secrets-gate warning costs exactly 5" 'echo "$OUT_WARN" | grep -q "^Score: 95/100$"'
assert "the recipe names secrets-gate" 'echo "$OUT_WARN" | grep -q "resolve warning in secrets-gate"'
# The recipe has to reproduce what hygiene actually ran. Seven of the eight
# sections are invoked with the project path, so a bare script path sent you to
# a different run — doctor without one exits 0 and shows nothing to fix.
assert "the recipe prints a runnable command, not a bare path" \
  'echo "$OUT_WARN" | grep -q "re-run: bash "'
assert "the recipe carries the project path hygiene used" \
  'echo "$OUT_WARN" | grep -qF "$BARE"'

OUT_OK="$("$HYG" "$WIRED" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean 2>&1)" || true
assert "a wired project scores 100" 'echo "$OUT_OK" | grep -q "^Score: 100/100$"'

OUT_SKIP="$("$HYG" "$BARE" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean --skip-secrets-gate 2>&1)"
assert "hygiene honours --skip-secrets-gate" '! echo "$OUT_SKIP" | grep -q "=== secrets-gate"'
assert "skipping the section restores 100" 'echo "$OUT_SKIP" | grep -q "^Score: 100/100$"'

print_summary_and_exit
