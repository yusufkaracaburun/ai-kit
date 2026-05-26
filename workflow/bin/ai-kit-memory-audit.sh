#!/usr/bin/env bash
# Audit .agents/memory/feedback/ for orphan + stale entries.
#
# Orphan  = file in feedback/ not referenced from MEMORY.md index
# Stale   = file not git-touched in >90 days AND zero project-wide refs
#
# Exit codes:
#   0 — clean (or no feedback dir / no MEMORY.md → skip)
#   1 — warnings (orphan or stale found)
#
# Report-only. Never deletes or rewrites.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
FEEDBACK_DIR="$PROJECT_PATH/.agents/memory/feedback"
MEMORY_INDEX="$PROJECT_PATH/.agents/memory/MEMORY.md"

if [ ! -d "$FEEDBACK_DIR" ]; then
  echo "memory-audit: no .agents/memory/feedback/ directory — skipped."
  exit 0
fi
if [ ! -f "$MEMORY_INDEX" ]; then
  echo "memory-audit: no .agents/memory/MEMORY.md — skipped."
  exit 0
fi

STALE_DAYS=90
NOW_EPOCH="$(date +%s)"
STALE_CUTOFF=$(( NOW_EPOCH - STALE_DAYS * 86400 ))

orphans=()
stale=()

shopt -s nullglob
for f in "$FEEDBACK_DIR"/*.md; do
  name="$(basename "$f" .md)"

  if ! grep -q "feedback/$name.md" "$MEMORY_INDEX"; then
    orphans+=("$name")
  fi

  if command -v git >/dev/null 2>&1 && git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    last_epoch="$(git -C "$PROJECT_PATH" log -1 --format=%at -- "${f#$PROJECT_PATH/}" 2>/dev/null)"
  else
    last_epoch=""
  fi
  if [ -z "$last_epoch" ]; then
    if stat -f %m "$f" >/dev/null 2>&1; then
      last_epoch="$(stat -f %m "$f")"
    else
      last_epoch="$(stat -c %Y "$f" 2>/dev/null || echo "$NOW_EPOCH")"
    fi
  fi

  if [ "$last_epoch" -lt "$STALE_CUTOFF" ]; then
    refs="$(grep -r -l "$name" --include="*.md" --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git "$PROJECT_PATH" 2>/dev/null | grep -v "^$f$" | wc -l | tr -d ' ')"
    if [ "$refs" = "0" ]; then
      age_days=$(( (NOW_EPOCH - last_epoch) / 86400 ))
      stale+=("$name (${age_days}d untouched, 0 refs)")
    fi
  fi
done
shopt -u nullglob

exit_code=0

if [ "${#orphans[@]}" -gt 0 ]; then
  echo "ORPHANS (not indexed in MEMORY.md):"
  for o in "${orphans[@]}"; do
    echo "  - $o"
  done
  echo "Fix: add a bullet under the relevant section in .agents/memory/MEMORY.md:"
  echo "     - [Title](feedback/<name>.md) — one-line hook"
  exit_code=1
fi

if [ "${#stale[@]}" -gt 0 ]; then
  [ "$exit_code" -eq 0 ] || echo ""
  echo "STALE (>${STALE_DAYS}d untouched + 0 refs):"
  for s in "${stale[@]}"; do
    echo "  - $s"
  done
  echo "Fix: confirm rule still applies, refresh content + re-commit, OR archive to .agents/memory/archive/."
  exit_code=1
fi

if [ "$exit_code" -eq 0 ]; then
  echo "memory-audit: feedback/ clean (all files indexed + fresh)."
fi

exit "$exit_code"
