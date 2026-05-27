#!/usr/bin/env bash
# Surface project-scoped hygiene-style skills the user can run separately,
# AND nudge the framework /ai:docs-sync when applicable (#96).
#
# Generic discovery — never bakes repo-specific knowledge into ai-kit.
# If a project keeps its own skills under .agents/skills/, list any that
# match hygiene-style triggers in their description so the hygiene flow
# points at them instead of duplicating their content.
#
# Triggers matched (case-insensitive substring in SKILL.md description):
#   docs-sync, doc-drift, docs-drift, repo-hygiene, housekeep, prune,
#   cleanup, audit
#
# After listing project-local skills (if any), also surface the framework
# /ai:docs-sync when it applies to the project (per the shared
# applicability helper). Both surfaces are deliberately shown side-by-side
# when both apply — project skill handles repo-specific drift, framework
# skill handles universal drift (dead links, repo-hygiene, finished-work).
#
# Exit codes:
#   0 — clean (no candidates, or candidates listed as info only)
#
# Report-only. Never invokes anything.
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/applicability.sh
source "$SCRIPT_BIN/lib/applicability.sh"

PROJECT_PATH="${1:-$PWD}"
SKILLS_DIR="$PROJECT_PATH/.agents/skills"

PROJECT_HITS=()

if [ -d "$SKILLS_DIR" ]; then
  shopt -s nullglob
  for d in "$SKILLS_DIR"/*/; do
    skill_file="$d/SKILL.md"
    [ -f "$skill_file" ] || continue
    name="$(basename "$d")"

    desc="$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_file" 2>/dev/null)"
    haystack="$(printf '%s %s' "$name" "$desc" | tr '[:upper:]' '[:lower:]')"

    for needle in docs-sync doc-drift docs-drift repo-hygiene housekeep prune cleanup audit; do
      if printf '%s' "$haystack" | grep -q "$needle"; then
        first_line_desc="$(printf '%s' "$desc" | cut -c1-100)"
        PROJECT_HITS+=("$name|$first_line_desc")
        break
      fi
    done
  done
  shopt -u nullglob
fi

DOCS_SYNC_APPLIES=0
if is_docs_sync_applicable "$PROJECT_PATH"; then
  DOCS_SYNC_APPLIES=1
fi

# Detect project-local docs-sync style specifically (for the "use which for what" hint).
PROJECT_HAS_DOCS_SYNC=0
for hit in "${PROJECT_HITS[@]+"${PROJECT_HITS[@]}"}"; do
  case "$hit" in
    docs-sync*|doc-drift*|docs-drift*) PROJECT_HAS_DOCS_SYNC=1 ;;
  esac
done

if [ "${#PROJECT_HITS[@]}" -eq 0 ] && [ "$DOCS_SYNC_APPLIES" -eq 0 ]; then
  echo "repo-skill-hint: no project-scoped hygiene skills found, /ai:docs-sync not applicable."
  exit 0
fi

if [ "${#PROJECT_HITS[@]}" -gt 0 ]; then
  echo "Project-scoped skills overlap with hygiene scope. Run separately if relevant:"
  for hit in "${PROJECT_HITS[@]}"; do
    name="${hit%%|*}"
    desc="${hit##*|}"
    if [ "$PROJECT_HAS_DOCS_SYNC" -eq 1 ] && [ "$DOCS_SYNC_APPLIES" -eq 1 ] && \
       { [ "$name" = "docs-sync" ] || [ "$name" = "doc-drift" ] || [ "$name" = "docs-drift" ]; }; then
      echo "  - /$name — repo-specific drift (uses your project's vocabulary, ADR triggers, status tables, etc.)"
    else
      echo "  - /$name — $desc"
    fi
  done
  echo "(These stay project-local — ai-kit's hygiene won't duplicate their content.)"
fi

if [ "$DOCS_SYNC_APPLIES" -eq 1 ]; then
  if [ "${#PROJECT_HITS[@]}" -gt 0 ]; then
    echo ""
    echo "Also applicable from the framework:"
  else
    echo "Framework skill applicable:"
  fi
  echo "  - /ai:docs-sync — universal drift (dead links, repo-hygiene, finished-work cleanup)"
fi

exit 0
