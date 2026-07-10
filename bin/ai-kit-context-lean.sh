#!/usr/bin/env bash
# Check always-loaded agent-context files for bloat.
#
# Root CLAUDE.md / AGENTS.md load into the context window at the start of
# EVERY session — a fixed token tax before the first prompt. Guidance:
# keep them under 200 lines; move directory-specific content into
# path-scoped files (subdirectory CLAUDE.md, scoped rules) that load on
# demand.
#
# Exit codes:
#   0 — clean (all files under threshold, or no files → skip silently)
#   1 — warning (at least one file over threshold)
#
# Report-only. Never edits.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
MAX_LINES=200

found=0
warned=0

for name in CLAUDE.md AGENTS.md; do
  f="$PROJECT_PATH/$name"
  [ -f "$f" ] || continue
  found=1
  # A file that IS a tool-managed block (Laravel Boost writes AGENTS.md
  # wholesale) is not user-curatable — its size is the tool's call.
  if head -1 "$f" | grep -q '^<laravel-boost-guidelines>'; then
    echo "note: $name is Boost-managed (<laravel-boost-guidelines>) — size is Boost's call, not curatable here; skipped."
    continue
  fi
  lines="$(wc -l < "$f" | tr -d ' ')"
  if [ "$lines" -gt "$MAX_LINES" ]; then
    warned=1
    echo "WARN: $name is $lines lines (>$MAX_LINES) — always loaded, fixed token tax every session."
  else
    echo "ok: $name — $lines lines (<=$MAX_LINES)."
  fi
done

if [ "$found" -eq 0 ]; then
  echo "context-lean: no root CLAUDE.md / AGENTS.md — skipped."
  exit 0
fi

if [ "$warned" -eq 1 ]; then
  cat <<'HINT'
Fix: keep only what every session needs (build commands, non-obvious
conventions, absolute rules). Move the rest out of the always-loaded path:
  - directory-specific notes -> <subdir>/CLAUDE.md (loads on demand)
  - stack conventions        -> path-scoped rules (.claude/rules, .cursor/rules globs)
  - multi-step procedures    -> a skill
Curation beats compression: moved content costs zero tokens per session.
HINT
  exit 1
fi

echo "context-lean: clean."
exit 0
