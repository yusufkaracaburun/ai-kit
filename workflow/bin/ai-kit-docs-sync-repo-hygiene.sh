#!/usr/bin/env bash
# Detect repo-hygiene findings — mechanical `find`-based checks only.
#
# Scope (locked from #88 grilling — DO NOT EXPAND):
#   * Empty directories (excl. .git, node_modules, vendor, etc.)
#   * Broken symlinks
#   * Orphan .agents/skills/<name>/ dirs (dir without SKILL.md)
#
# NO AST analysis. NO "dead code" detection. NO content scans.
#
# Fix flow (two-step, group-confirmable for safe ops, never for orphans):
#   - Empty dirs       → group-confirmable rmdir on accept
#   - Broken symlinks  → group-confirmable rm on accept
#   - Orphan skill dirs → REPORT-ONLY (in-progress work guard)
#
# Exit codes:
#   0 — nothing found
#   1 — one or more findings
#   2 — error
set -uo pipefail

PROJECT_PATH=""
NO_PROMPT=0

for arg in "$@"; do
  case "$arg" in
    --no-prompt) NO_PROMPT=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "repo-hygiene: project path does not exist: $PROJECT_PATH" >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

[ -t 0 ] || NO_PROMPT=1

# Shared exclude logic: basename excludes + path-prefix excludes (active git
# worktrees + `.docs-sync-ignore`). See bin/lib/docs-sync-excludes.sh.
SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/docs-sync-excludes.sh
source "$SCRIPT_BIN/lib/docs-sync-excludes.sh"

PRUNE_ARGS="$(dsync_build_prune_args "$PROJECT_PATH")"

# Empty dirs.
EMPTY_DIRS=()
while IFS= read -r d; do
  [ -z "$d" ] && continue
  EMPTY_DIRS+=("$d")
done < <(
  find "$PROJECT_PATH" \
    -type d \( $PRUNE_ARGS \) -prune -o \
    -type d -empty -print 2>/dev/null \
  | grep -v "^$PROJECT_PATH$" \
  | dsync_filter_path_prefixes "$PROJECT_PATH" \
  | sort
)

# Broken symlinks. `-xtype l` is GNU-only; on BSD/macOS find we list every
# symlink then test the target with `[ ! -e ]`. Portable across both.
BROKEN_SYMLINKS=()
while IFS= read -r s; do
  [ -z "$s" ] && continue
  [ -e "$s" ] && continue
  BROKEN_SYMLINKS+=("$s")
done < <(
  find "$PROJECT_PATH" \
    -type d \( $PRUNE_ARGS \) -prune -o \
    -type l -print 2>/dev/null \
  | dsync_filter_path_prefixes "$PROJECT_PATH" \
  | sort
)

# Orphan skill dirs — under .agents/skills/<name>/ without a SKILL.md.
ORPHAN_SKILL_DIRS=()
SKILLS_ROOT="$PROJECT_PATH/.agents/skills"
if [ -d "$SKILLS_ROOT" ]; then
  shopt -s nullglob
  for d in "$SKILLS_ROOT"/*/; do
    if [ ! -f "$d/SKILL.md" ]; then
      ORPHAN_SKILL_DIRS+=("${d%/}")
    fi
  done
  shopt -u nullglob
fi

TOTAL=$(( ${#EMPTY_DIRS[@]} + ${#BROKEN_SYMLINKS[@]} + ${#ORPHAN_SKILL_DIRS[@]} ))

if [ "$TOTAL" -eq 0 ]; then
  echo "repo-hygiene: 0 findings — clean."
  exit 0
fi

echo "repo-hygiene: $TOTAL finding(s):"
echo ""

if [ "${#EMPTY_DIRS[@]}" -gt 0 ]; then
  echo "  Empty directories (${#EMPTY_DIRS[@]}):"
  for d in "${EMPTY_DIRS[@]}"; do
    printf '    %s\n' "${d#$PROJECT_PATH/}"
  done
  echo ""
fi

if [ "${#BROKEN_SYMLINKS[@]}" -gt 0 ]; then
  echo "  Broken symlinks (${#BROKEN_SYMLINKS[@]}):"
  for s in "${BROKEN_SYMLINKS[@]}"; do
    target="$(readlink "$s" 2>/dev/null || echo '<unreadable>')"
    printf '    %s -> %s\n' "${s#$PROJECT_PATH/}" "$target"
  done
  echo ""
fi

if [ "${#ORPHAN_SKILL_DIRS[@]}" -gt 0 ]; then
  echo "  Orphan .agents/skills/ dirs (no SKILL.md — ${#ORPHAN_SKILL_DIRS[@]}) [report-only]:"
  for d in "${ORPHAN_SKILL_DIRS[@]}"; do
    printf '    %s\n' "${d#$PROJECT_PATH/}"
  done
  echo "  (Skill dirs without SKILL.md may be in-progress work — never auto-deleted.)"
  echo ""
fi

# Fix prompt (group-confirmable for safe ops only).
# `AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1` is a test-only escape: it simulates the
# user answering "y" to the group-confirm prompt without needing a TTY. Never
# document or use in production — the entire safety of this section is the
# explicit prompt.
PROMPT_FIRED=0
if [ "$NO_PROMPT" -eq 0 ] && { [ "${#EMPTY_DIRS[@]}" -gt 0 ] || [ "${#BROKEN_SYMLINKS[@]}" -gt 0 ]; }; then
  PROMPT_FIRED=1
  local_total=$(( ${#EMPTY_DIRS[@]} + ${#BROKEN_SYMLINKS[@]} ))
  printf 'Fix %d safe item(s) now (rmdir empty dirs + rm broken symlinks)? [y/N] ' "$local_total"
  read -r reply || reply=""
elif [ "${AI_KIT_DOCS_SYNC_TEST_AUTO_YES:-0}" = "1" ] && \
     { [ "${#EMPTY_DIRS[@]}" -gt 0 ] || [ "${#BROKEN_SYMLINKS[@]}" -gt 0 ]; }; then
  PROMPT_FIRED=1
  reply="y"
fi

if [ "$PROMPT_FIRED" -eq 1 ] && { [ "$reply" = "y" ] || [ "$reply" = "Y" ]; }; then
  for d in "${EMPTY_DIRS[@]}"; do
    if rmdir "$d" 2>/dev/null; then
      echo "  rmdir: ${d#$PROJECT_PATH/}"
    else
      echo "  rmdir FAILED: ${d#$PROJECT_PATH/}" >&2
    fi
  done
  for s in "${BROKEN_SYMLINKS[@]}"; do
    if rm "$s" 2>/dev/null; then
      echo "  rm: ${s#$PROJECT_PATH/}"
    else
      echo "  rm FAILED: ${s#$PROJECT_PATH/}" >&2
    fi
  done
fi

exit 1
