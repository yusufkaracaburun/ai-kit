#!/usr/bin/env bash
# Run all ai-kit hygiene checks in one shot:
#   1. ai-kit-doctor.sh          — install health
#   2. ai-kit-dedupe.sh          — duplicate skills/agents/rules
#   3. audit-setup-symmetry.sh   — catalog ↔ wiring symmetry
#   4. ai-kit-memory-audit.sh    — orphan / stale entries across all .agents/memory/*/ subdirs
#   5. ai-kit-repo-skill-hint.sh — surface project-scoped hygiene skills (docs-sync, etc.)
#
# Exit code = max of the sections (0 clean, 1 warn, 2 block).
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<USAGE
Usage: $0 [path] [--skip-doctor] [--skip-dedupe] [--skip-symmetry] [--skip-memory] [--skip-repo-skills]

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

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --skip-doctor)     SKIP_DOCTOR=1 ;;
    --skip-dedupe)     SKIP_DEDUPE=1 ;;
    --skip-symmetry)   SKIP_SYMMETRY=1 ;;
    --skip-memory)     SKIP_MEMORY=1 ;;
    --skip-repo-skills) SKIP_REPO_SKILLS=1 ;;
    -*) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"

max_exit=0
record() {
  local code="$1"
  [ "$code" -gt "$max_exit" ] && max_exit="$code"
}

section() {
  printf '\n=== %s ===\n' "$1"
}

if [ "$SKIP_DOCTOR" -eq 0 ]; then
  section "doctor (install health)"
  bash "$AIKIT/bin/ai-kit-doctor.sh" "$PROJECT_PATH"
  record "$?"
fi

if [ "$SKIP_DEDUPE" -eq 0 ]; then
  section "dedupe (duplicate skills/agents/rules)"
  bash "$AIKIT/bin/ai-kit-dedupe.sh" "$PROJECT_PATH"
  record "$?"
fi

if [ "$SKIP_SYMMETRY" -eq 0 ]; then
  section "audit-setup-symmetry (catalog ↔ wiring)"
  bash "$AIKIT/bin/audit-setup-symmetry.sh"
  record "$?"
fi

if [ "$SKIP_MEMORY" -eq 0 ]; then
  section "memory-audit (orphan/stale across .agents/memory/*/)"
  bash "$AIKIT/bin/ai-kit-memory-audit.sh" "$PROJECT_PATH"
  record "$?"
fi

if [ "$SKIP_REPO_SKILLS" -eq 0 ]; then
  section "repo-skill-hint (project-scoped hygiene skills)"
  bash "$AIKIT/bin/ai-kit-repo-skill-hint.sh" "$PROJECT_PATH"
  record "$?"
fi

section "summary"
case "$max_exit" in
  0) echo "hygiene: all sections clean." ;;
  1) echo "hygiene: warnings found (exit 1)." ;;
  *) echo "hygiene: blockers found (exit $max_exit)." ;;
esac

exit "$max_exit"
