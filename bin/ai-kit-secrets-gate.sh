#!/usr/bin/env bash
# Hygiene section: is this project's secret-prevention gate still wired?
#
# It grades the wiring, never the history. A full history scan costs tens of
# seconds on a mid-sized repo and returns the same answer every time until
# somebody commits — running it from hygiene would end hygiene's usability as
# a command you reach for casually, and re-deriving an unchanged answer is
# waste. What actually decays is the wiring: a workflow file someone deleted,
# a guard line lost when a hook was regenerated. That is what this reads, as
# a filesystem check costing milliseconds.
#
# Exit 0 = wired (or nothing to grade), 1 = warning. Never above 1: a missing
# optional gate is not a broken install, and blocker weight in this repo's
# score model is reserved for things that are.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
TARGET="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "secrets-gate: $PROJECT_PATH is not a directory — skipped."
  exit 0
}

# A directory git does not track cannot carry a gate, and warning about it
# would be noise in every non-repo hygiene run.
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "secrets-gate: not a git repository — skipped."
  exit 0
fi

CI="$TARGET/.github/workflows/gitleaks.yml"
CI_OK=false
[ -f "$CI" ] && CI_OK=true

# Resolve the pre-commit hook the same way the emitter does, so the check
# recognises exactly what it produced. A configured hooks path or a husky
# directory is the mechanism; a project with neither has no pre-commit story
# and must not be marked down for the half it cannot have.
HOOKS_PATH="$(git -C "$TARGET" config --get core.hooksPath 2>/dev/null || true)"
if [ -n "$HOOKS_PATH" ] || [ -d "$TARGET/.husky" ]; then
  case "$HOOKS_PATH$([ -d "$TARGET/.husky" ] && echo .husky)" in
    *.husky*) HOOK="$TARGET/.husky/pre-commit" ;;
    *) HOOK="$TARGET/$HOOKS_PATH/pre-commit" ;;
  esac
  HAS_MECHANISM=true
else
  HOOK="$TARGET/.git/hooks/pre-commit"
  HAS_MECHANISM=false
  [ -f "$HOOK" ] && HAS_MECHANISM=true
fi

HOOK_OK=false
if [ "$HAS_MECHANISM" = true ] && [ -f "$HOOK" ] && grep -q 'gitleaks protect' "$HOOK" 2>/dev/null; then
  HOOK_OK=true
fi

if [ "$CI_OK" = true ]; then
  echo "ok: CI workflow present — .github/workflows/gitleaks.yml"
else
  echo "warn: no gitleaks CI workflow."
fi

if [ "$HAS_MECHANISM" = false ]; then
  echo "ok: no pre-commit mechanism to extend — CI carries the guarantee."
elif [ "$HOOK_OK" = true ]; then
  echo "ok: pre-commit guard present — ${HOOK#"$TARGET"/}"
else
  echo "warn: pre-commit mechanism present but carries no gitleaks guard — ${HOOK#"$TARGET"/}"
fi

if [ "$CI_OK" = true ] && { [ "$HAS_MECHANISM" = false ] || [ "$HOOK_OK" = true ]; }; then
  echo "secrets-gate: wired."
  exit 0
fi

cat <<'HINT'
Fix: wire the gate. CI is the half nothing bypasses; the pre-commit guard is
appended only where a mechanism already exists.
  bash "$AI_KIT_ROOT/bin/apply-secrets-gate.sh" <project-path>
This grades wiring only — to see what is already in the history, run
ai-kit-secrets-scan.sh separately.
HINT
exit 1
