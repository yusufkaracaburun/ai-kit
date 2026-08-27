#!/usr/bin/env bash
# Check always-loaded agent-context files for bloat.
#
# Two sources of fixed, always-loaded-every-session token tax:
#   1. Root CLAUDE.md / AGENTS.md — loaded before the first prompt.
#   2. The SessionStart always-on rule injection hook
#      (bin/hooks/session-rules-inject.sh, issue #144) — same kind of tax,
#      paid once per session instead of living in an editable file, so it
#      needs its own line here rather than being invisible to this check.
#
# Guidance: keep CLAUDE.md/AGENTS.md under 200 lines; move directory-specific
# content into path-scoped files that load on demand. The injected rule
# budget is capped by the hook itself (weight: high only, smallest-first,
# same order of magnitude as the 200-line ceiling below) — this check
# reports what it actually injected, it does not enforce a second,
# independent limit of its own.
#
# Exit codes:
#   0 — clean (all files/injection under threshold, or nothing to check)
#   1 — warning (CLAUDE.md/AGENTS.md over threshold, or injected rules over
#       the budget this check expects)
#
# Report-only. Never edits.
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${1:-$PWD}"
MAX_LINES=200
MAX_INJECT_WORDS=2000

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

HOOK="$SCRIPT_BIN/hooks/session-rules-inject.sh"
if [ -d "$PROJECT_PATH/.claude/rules" ] && [ -x "$HOOK" ]; then
  inject_report="$(CLAUDE_PROJECT_DIR="$PROJECT_PATH" "$HOOK" --report </dev/null 2>/dev/null || true)"
  inject_words="$(printf '%s' "$inject_report" | sed -n 's/^rules=[0-9]* words=\([0-9]*\).*/\1/p')"
  inject_rules="$(printf '%s' "$inject_report" | sed -n 's/^rules=\([0-9]*\).*/\1/p')"
  if [ -n "$inject_words" ] && [ "$inject_words" -gt 0 ]; then
    found=1
    if [ "$inject_words" -gt "$MAX_INJECT_WORDS" ]; then
      warned=1
      echo "WARN: SessionStart rule injection is $inject_words words (>$MAX_INJECT_WORDS, $inject_rules rule(s)) — always loaded every session."
    else
      echo "ok: SessionStart rule injection — $inject_rules rule(s), $inject_words words (<=$MAX_INJECT_WORDS)."
    fi
  fi
fi

if [ "$found" -eq 0 ]; then
  echo "context-lean: no root CLAUDE.md / AGENTS.md / injected rules — skipped."
  exit 0
fi

if [ "$warned" -eq 1 ]; then
  cat <<'HINT'
Fix: keep only what every session needs (build commands, non-obvious
conventions, absolute rules). Move the rest out of the always-loaded path:
  - directory-specific notes -> <subdir>/CLAUDE.md (loads on demand)
  - stack conventions        -> path-scoped rules (.claude/rules, .cursor/rules globs)
  - multi-step procedures    -> a skill
  - SessionStart injection   -> lower the rule's weight to medium/low, or set
                                the machine-wide opt-out
                                (bin/ai-kit-no-rule-injection.sh on)
Curation beats compression: moved content costs zero tokens per session.
HINT
  exit 1
fi

echo "context-lean: clean."
exit 0
