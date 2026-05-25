#!/usr/bin/env bash
# Audit that every standards/external/*.json catalog has a matching wiring
# path — either consumed by the recommend-tools.sh scorer (which Branch 14
# in setup/SKILL.md fires) or surfaced by its own setup branch.
#
# Closes the #48 (setup symmetry meta) DoD lock: future catalogs cannot
# land without a wiring path, otherwise this check fails.
#
# Exit codes: 0 = all catalogs wired; 1 = unwired catalog found.

set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

EXTERNAL_DIR="$AIKIT/standards/external"
SCORER_LIB="$AIKIT/bin/lib/recommend-tools-lib.sh"
SETUP_SKILL="$AIKIT/workflow/skills/setup/SKILL.md"

[ -d "$EXTERNAL_DIR" ] || { echo "Missing: $EXTERNAL_DIR" >&2; exit 2; }
[ -f "$SCORER_LIB" ] || { echo "Missing: $SCORER_LIB" >&2; exit 2; }
[ -f "$SETUP_SKILL" ] || { echo "Missing: $SETUP_SKILL" >&2; exit 2; }

# Catalogs that are explicitly NOT consumed by recommend-tools.sh and have
# no setup branch by design (e.g. exclusion lists, internal-only data).
EXCLUDED=("plugins-excluded.json" "VETTING.md")

is_excluded() {
  local name="$1" e
  for e in "${EXCLUDED[@]}"; do
    [ "$name" = "$e" ] && return 0
  done
  return 1
}

FAIL=0
for path in "$EXTERNAL_DIR"/*.json; do
  [ -f "$path" ] || continue
  name="$(basename "$path")"
  if is_excluded "$name"; then continue; fi

  # Catalog must be referenced in the scorer lib OR explicitly wired in
  # setup/SKILL.md as its own branch.
  if grep -q "$name" "$SCORER_LIB"; then
    echo "OK  $name → wired via recommend-tools scorer"
  elif grep -q "$name" "$SETUP_SKILL"; then
    echo "OK  $name → wired via setup/SKILL.md branch"
  else
    echo "FAIL $name → no wiring path found (add to $SCORER_LIB or setup/SKILL.md)"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "Symmetry audit FAILED. See https://github.com/yusufkaracaburun/ai-kit/issues/48"
  exit 1
fi
exit 0
