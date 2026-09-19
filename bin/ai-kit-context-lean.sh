#!/usr/bin/env bash
# Check always-loaded agent-context files for bloat.
#
# Two sources of fixed, always-loaded-every-session token tax:
#   1. Root CLAUDE.md / AGENTS.md — loaded before the first prompt.
#   2. Every .claude/rules/*.md WITHOUT `paths:` frontmatter — Claude Code
#      loads those natively at session start, all of them, no budget (#182,
#      measured 2026-09-19). A rule with `paths:` loads only on touch and is
#      not counted.
#
# Guidance: keep CLAUDE.md/AGENTS.md under 200 lines; move directory-specific
# content into path-scoped files that load on demand. Pathless rules get the
# same order-of-magnitude ceiling (200 lines ~ 2k words).
#
# Exit codes:
#   0 — clean (all files/rules under threshold, or nothing to check)
#   1 — warning (CLAUDE.md/AGENTS.md over threshold, or pathless rules over
#       the word budget)
#
# Report-only. Never edits.
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${1:-$PWD}"
MAX_LINES=200
MAX_RULE_WORDS=2000

found=0
warned=0

for name in CLAUDE.md AGENTS.md; do
  f="$PROJECT_PATH/$name"
  [ -f "$f" ] || continue
  found=1
  # Laravel Boost writes a <laravel-boost-guidelines> block that is
  # tool-managed, not user-curatable — exclude it from the count, whether
  # it's the whole file (Boost's own AGENTS.md target) or appended below
  # hand-authored content (Boost's default CLAUDE.md target).
  boost_line="$(grep -n '^<laravel-boost-guidelines>' "$f" | head -1 | cut -d: -f1)"
  if [ "$boost_line" = "1" ]; then
    echo "note: $name is Boost-managed (<laravel-boost-guidelines>) — size is Boost's call, not curatable here; skipped."
    continue
  elif [ -n "$boost_line" ]; then
    lines=$((boost_line - 1))
    echo "note: $name has a Boost-managed block from line $boost_line — excluded from the count below."
  else
    lines="$(wc -l < "$f" | tr -d ' ')"
  fi
  if [ "$lines" -gt "$MAX_LINES" ]; then
    warned=1
    echo "WARN: $name is $lines lines (>$MAX_LINES) — always loaded, fixed token tax every session."
  else
    echo "ok: $name — $lines lines (<=$MAX_LINES)."
  fi
done

# Pathless rules split in two: the kit's own universal set (every project
# gets it from /ai:setup — its size is a kit decision, reported as a note,
# never scored against the project) and everything else pathless (stack
# rules without a scope, hand-written files) — that is the project's tax
# and the only part that warns.
RULES_DIR="$PROJECT_PATH/.claude/rules"
KIT_RULES="$SCRIPT_BIN/../standards/rules"
is_universal_rule() {
  # The emitted header names the source as standards/rules/<name>.mini.md,
  # bare for feedback/ rules and .mini for .nano ones — resolve like
  # emit-rules.sh does.
  local name cand ext
  name="$(head -5 "$1" | sed -n 's|.*from standards/rules/\([^ ]*\)\.mini\.md.*|\1|p' | head -1)"
  [ -n "$name" ] || return 1
  for cand in "$name" "feedback/$name"; do
    for ext in mini.md nano.md; do
      [ -f "$KIT_RULES/$cand.$ext" ] && { grep -q '^universal: true' "$KIT_RULES/$cand.$ext"; return; }
    done
  done
  return 1
}
if [ -d "$RULES_DIR" ]; then
  uni_words=0; uni_count=0; other_words=0; other_count=0
  while IFS= read -r f; do
    sed -n '2,/^---$/p' "$f" | grep -q '^paths:' && continue   # scoped → loads on touch
    w="$(wc -w < "$f")"
    if is_universal_rule "$f"; then
      uni_words=$((uni_words + w)); uni_count=$((uni_count + 1))
    else
      other_words=$((other_words + w)); other_count=$((other_count + 1))
    fi
  done < <(find "$RULES_DIR" -name '*.md' \( -type f -o -type l \))   # symlinked rules load too
  if [ "$uni_count" -gt 0 ]; then
    found=1
    echo "note: $uni_count universal ai-kit rule(s), $uni_words words — loaded natively every session (kit default, not scored here)."
  fi
  if [ "$other_count" -gt 0 ]; then
    found=1
    if [ "$other_words" -gt "$MAX_RULE_WORDS" ]; then
      warned=1
      echo "WARN: $other_count pathless non-universal rule(s) in .claude/rules — $other_words words (>$MAX_RULE_WORDS) loaded natively every session."
    else
      echo "ok: .claude/rules — $other_count pathless non-universal rule(s), $other_words words (<=$MAX_RULE_WORDS) loaded every session."
    fi
  fi
fi

if [ "$found" -eq 0 ]; then
  echo "context-lean: no root CLAUDE.md / AGENTS.md / pathless rules — skipped."
  exit 0
fi

if [ "$warned" -eq 1 ]; then
  cat <<'HINT'
Fix: keep only what every session needs (build commands, non-obvious
conventions, absolute rules). Move the rest out of the always-loaded path:
  - directory-specific notes -> <subdir>/CLAUDE.md (loads on demand)
  - stack conventions        -> path-scoped rules (.claude/rules, .cursor/rules globs)
  - multi-step procedures    -> a skill
  - pathless .claude/rules   -> give the rule `paths:` in its source (loads
                                on touch), set default_mode: on-demand, or
                                drop it from this project's emitted set
Curation beats compression: moved content costs zero tokens per session.
HINT
  exit 1
fi

echo "context-lean: clean."
exit 0
