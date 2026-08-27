#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ai-kit-memory-audit.sh scans a project's .agents/memory/ for orphan
# (unindexed) and stale (untouched + unreferenced) entries. It never
# touches $HOME — every case operates on a throwaway project directory.
# Report-only: never deletes or rewrites, so there is nothing to verify was
# left untouched beyond the source files themselves.

memory_audit() {
  # memory_audit <project-path>
  bash "$AIKIT/bin/ai-kit-memory-audit.sh" "$1"
}

echo "=== skip conditions ==="
T=$(mktemp -d)
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "no .agents/memory/ dir -> skip message" 'grep -q "no .agents/memory/ directory" <<<"$OUT"'
assert "no .agents/memory/ dir -> exit 0" '[ "$RC" -eq 0 ]'
rm -rf "$T"

T=$(mktemp -d)
mkdir -p "$T/.agents/memory/feedback"
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "memory dir without MEMORY.md -> skip message" 'grep -q "no .agents/memory/MEMORY.md" <<<"$OUT"'
assert "memory dir without MEMORY.md -> exit 0" '[ "$RC" -eq 0 ]'
rm -rf "$T"

echo "=== clean: indexed + fresh ==="
T=$(mktemp -d)
mkdir -p "$T/.agents/memory/feedback"
echo "content" > "$T/.agents/memory/feedback/note-a.md"
echo "- [Note A](feedback/note-a.md) — hook" > "$T/.agents/memory/MEMORY.md"
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "indexed + fresh file -> clean" 'grep -q "memory-audit: clean" <<<"$OUT"'
assert "clean -> exit 0" '[ "$RC" -eq 0 ]'
rm -rf "$T"

echo "=== orphan: not indexed, but fresh ==="
T=$(mktemp -d)
mkdir -p "$T/.agents/memory/feedback"
echo "content" > "$T/.agents/memory/feedback/note-b.md"
echo "# empty index" > "$T/.agents/memory/MEMORY.md"
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "unindexed file flagged as orphan" 'grep -q "feedback/note-b" <<<"$OUT"'
assert "fresh file is NOT also flagged stale" '! grep -q "STALE" <<<"$OUT"'
assert "orphan -> exit 1" '[ "$RC" -eq 1 ]'
rm -rf "$T"

echo "=== stale: not indexed, old, unreferenced elsewhere ==="
T=$(mktemp -d)
mkdir -p "$T/.agents/memory/feedback"
echo "content" > "$T/.agents/memory/feedback/note-c.md"
echo "# unrelated index content" > "$T/.agents/memory/MEMORY.md"
touch -t 202001010000 "$T/.agents/memory/feedback/note-c.md"
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "old + unreferenced file flagged stale" 'grep -q "STALE" <<<"$OUT" && grep -q "feedback/note-c" <<<"$OUT"'
assert "warnings -> exit 1" '[ "$RC" -eq 1 ]'
rm -rf "$T"

echo "=== indexed + old: NOT flagged (documents current behaviour) ==="
# The stale branch only fires when `refs` is 0, and it counts MEMORY.md itself.
# So indexing a file creates the very reference that disqualifies it from ever
# being called stale: a tidily-indexed memory rots unnoticed, an untidy one is
# caught. This test pins what the script does today, not what it should do —
# the design question is #147.
T=$(mktemp -d)
mkdir -p "$T/.agents/memory/feedback"
echo "content" > "$T/.agents/memory/feedback/note-d.md"
echo "- [Note D](feedback/note-d.md) — hook" > "$T/.agents/memory/MEMORY.md"
touch -t 202001010000 "$T/.agents/memory/feedback/note-d.md"
RC=0; OUT=$(memory_audit "$T") || RC=$?
assert "indexed + very old file is reported clean (see #147)" 'grep -q "memory-audit: clean" <<<"$OUT"'
assert "indexed + very old file -> exit 0 (see #147)" '[ "$RC" -eq 0 ]'
rm -rf "$T"

print_summary_and_exit
