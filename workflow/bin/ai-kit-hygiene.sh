#!/usr/bin/env bash
# Run all ai-kit hygiene checks in one shot:
#   1. ai-kit-doctor.sh          — install health
#   2. ai-kit-dedupe.sh          — duplicate skills/agents/rules
#   3. audit-setup-symmetry.sh   — catalog ↔ wiring symmetry
#   4. ai-kit-memory-audit.sh    — orphan / stale entries across all .agents/memory/*/ subdirs
#   5. ai-kit-repo-skill-hint.sh — surface project-scoped hygiene skills (docs-sync, etc.)
#   6. ai-kit-context-lean.sh    — always-loaded CLAUDE.md/AGENTS.md over 200 lines
#   7. ai-kit-secrets-gate.sh    — secret-prevention wiring (never scans history)
#   8. ai-kit-upstream-drift.sh  — vendored upstreams that moved past their pin
#                                  (ai-kit repo only — consumer projects vendor nothing)
#
# Exit code = max of the sections (0 clean, 1 warn, 2 block).
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<USAGE
Usage: $0 [path] [--skip-doctor] [--skip-dedupe] [--skip-symmetry] [--skip-memory] [--skip-repo-skills] [--skip-context-lean] [--skip-upstream-drift]

Runs ai-kit hygiene checks against the given project path (default: cwd).
Exit code = max of the section exit codes (0 clean, 1 warn, 2 block).
USAGE
}

PROJECT_PATH=""
SKIP_DOCTOR=0
SKIP_DEDUPE=0
SKIP_SYMMETRY=0
SKIP_MEMORY=0
SKIP_REPO_SKILLS=0
SKIP_CONTEXT_LEAN=0
SKIP_SECRETS_GATE=0
SKIP_UPSTREAM_DRIFT=0

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --skip-doctor)     SKIP_DOCTOR=1 ;;
    --skip-dedupe)     SKIP_DEDUPE=1 ;;
    --skip-symmetry)   SKIP_SYMMETRY=1 ;;
    --skip-memory)     SKIP_MEMORY=1 ;;
    --skip-repo-skills) SKIP_REPO_SKILLS=1 ;;
    --skip-context-lean) SKIP_CONTEXT_LEAN=1 ;;
    --skip-secrets-gate) SKIP_SECRETS_GATE=1 ;;
    --skip-upstream-drift) SKIP_UPSTREAM_DRIFT=1 ;;
    -*) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"

max_exit=0
# Parallel arrays — index N holds the section name + exit code for the Nth
# check that ran. Used by the scoring block at the end to produce ranked
# "fix this to gain +N" recommendations alongside the numeric grade.
SECTION_NAMES=()
SECTION_CODES=()
record() {
  local code="$1"
  local name="$2"
  [ "$code" -gt "$max_exit" ] && max_exit="$code"
  SECTION_NAMES+=("$name")
  SECTION_CODES+=("$code")
}

section() {
  printf '\n=== %s ===\n' "$1"
}

if [ "$SKIP_DOCTOR" -eq 0 ]; then
  section "doctor (install health)"
  bash "$AIKIT/bin/ai-kit-doctor.sh" "$PROJECT_PATH"
  record "$?" "doctor"
fi

if [ "$SKIP_DEDUPE" -eq 0 ]; then
  section "dedupe (duplicate skills/agents/rules)"
  bash "$AIKIT/bin/ai-kit-dedupe.sh" "$PROJECT_PATH"
  record "$?" "dedupe"
fi

if [ "$SKIP_SYMMETRY" -eq 0 ]; then
  section "audit-setup-symmetry (catalog ↔ wiring)"
  bash "$AIKIT/bin/audit-setup-symmetry.sh"
  record "$?" "audit-setup-symmetry"
fi

if [ "$SKIP_MEMORY" -eq 0 ]; then
  section "memory-audit (orphan/stale across .agents/memory/*/)"
  bash "$AIKIT/bin/ai-kit-memory-audit.sh" "$PROJECT_PATH"
  record "$?" "memory-audit"
fi

if [ "$SKIP_REPO_SKILLS" -eq 0 ]; then
  section "repo-skill-hint (project-scoped hygiene skills)"
  bash "$AIKIT/bin/ai-kit-repo-skill-hint.sh" "$PROJECT_PATH"
  record "$?" "repo-skill-hint"
fi

if [ "$SKIP_CONTEXT_LEAN" -eq 0 ]; then
  section "context-lean (always-loaded CLAUDE.md/AGENTS.md size)"
  bash "$AIKIT/bin/ai-kit-context-lean.sh" "$PROJECT_PATH"
  record "$?" "context-lean"
fi

if [ "$SKIP_SECRETS_GATE" -eq 0 ]; then
  section "secrets-gate (prevention wiring, not history)"
  bash "$AIKIT/bin/ai-kit-secrets-gate.sh" "$PROJECT_PATH"
  record "$?" "secrets-gate"
fi

# Only ai-kit itself carries standards/external/vendored.json. A consumer
# project has no vendored upstreams, so the section stays silent there rather
# than printing an empty report on every /ai:hygiene run.
if [ "$SKIP_UPSTREAM_DRIFT" -eq 0 ] && [ -f "$PROJECT_PATH/standards/external/vendored.json" ]; then
  section "upstream-drift (vendored copies vs upstream pin)"
  bash "$AIKIT/bin/ai-kit-upstream-drift.sh"
  record "$?" "upstream-drift"
fi

section "summary"
case "$max_exit" in
  0) echo "hygiene: all sections clean." ;;
  1) echo "hygiene: warnings found (exit 1)." ;;
  *) echo "hygiene: blockers found (exit $max_exit)." ;;
esac

# Score: start at 100, subtract per-section penalty (block=-20, warn=-5,
# clean=0). Floor at 0. Always printed — even on a fully clean run, so
# the number is the canonical install-quality signal.
score=100
fix_lines=()
# Map section name → standalone script path. audit-setup-symmetry is the
# odd one out — no ai-kit- prefix on disk.
section_script() {
  case "$1" in
    audit-setup-symmetry) echo "$AIKIT/bin/audit-setup-symmetry.sh" ;;
    *) echo "$AIKIT/bin/ai-kit-$1.sh" ;;
  esac
}
i=0
while [ "$i" -lt "${#SECTION_CODES[@]}" ]; do
  code="${SECTION_CODES[$i]}"
  name="${SECTION_NAMES[$i]}"
  script="$(section_script "$name")"
  case "$code" in
    0) : ;;
    1)
      score=$(( score - 5 ))
      fix_lines+=("  +5   resolve warning in $name (re-run $script standalone)")
      ;;
    *)
      score=$(( score - 20 ))
      fix_lines+=("  +20  fix blocker in $name (re-run $script standalone)")
      ;;
  esac
  i=$(( i + 1 ))
done
[ "$score" -lt 0 ] && score=0

printf '\nScore: %d/100\n' "$score"
if [ "${#fix_lines[@]}" -gt 0 ]; then
  echo "To reach 100:"
  # Sort blockers (+20) before warnings (+5) — bash sort by first column descending.
  printf '%s\n' "${fix_lines[@]}" | sort -r
fi

exit "$max_exit"
