#!/usr/bin/env bash
# Compute canonical ai-kit primitive counts from filesystem reality + verify
# that user-facing docs/manifests carry the same numbers.
#
# Usage:
#   count-primitives.sh                # emit JSON {"skills":N,…}
#   count-primitives.sh --human        # one-liner "37 skills · 10 commands · 30 rules · 3 subagents"
#   count-primitives.sh --check        # exit 1 when docs/plugin.json drift from reality
#
# Single-source-of-truth: bin/count-primitives.sh. Anything else that prints
# these numbers should either call this script or be checked against it.

set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

count_skills()    { find "$PRIMITIVES/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' '; }
count_commands()  { find "$PRIMITIVES/commands" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }
count_rules()     { find "$AIKIT/standards/rules" -mindepth 1 -maxdepth 1 -name '*.mini.md' 2>/dev/null | wc -l | tr -d ' '; }
count_subagents() { find "$PRIMITIVES/agents" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }

emit_json() {
  printf '{"skills":%s,"commands":%s,"rules":%s,"subagents":%s}\n' \
    "$(count_skills)" "$(count_commands)" "$(count_rules)" "$(count_subagents)"
}

emit_human() {
  printf '%s skills · %s commands · %s rules · %s subagents\n' \
    "$(count_skills)" "$(count_commands)" "$(count_rules)" "$(count_subagents)"
}

# Each tuple: file:pattern_template (where %SKILLS%/%COMMANDS%/%RULES% are
# the canonical numbers). Checker substitutes the current counts and asserts
# the rendered pattern appears in the file. Missing file → silent skip; the
# checker only flags files that exist and disagree.
#
# Pattern templates are intentionally specific phrases — not full lines — so
# minor formatting around them is OK.
PATTERNS=(
  "README.md|%RULES% canonical mini-rules"
  "README.md|%COMMANDS% slash commands"
  "README.md|| Skills | %SKILLS% |"
  "README.md|| Slash commands | %COMMANDS% |"
  "README.md|%SKILLS% skills covering one loop"
  "docs/diagrams.md|%SKILLS% skills"
  "docs/diagrams.md|%COMMANDS% slash commands"
  "docs/diagrams.md|%RULES% agent-agnostic rules"
  "docs/install-plugin.md|All %SKILLS% skills"
  "docs/install-plugin.md|All %COMMANDS% slash commands"
  "docs/mental-model.md|How the %SKILLS% skills"
  "docs/mental-model.md|%COMMANDS% slash commands"
  "workflow/.claude-plugin/plugin.json|%SKILLS% skills"
  "workflow/.claude-plugin/plugin.json|%COMMANDS% slash commands"
  "workflow/.claude-plugin/plugin.json|%RULES% canonical rules"
  "workflow/.cursor-plugin/plugin.json|%SKILLS% skills"
  "workflow/.cursor-plugin/plugin.json|%COMMANDS% commands"
  "ONBOARDING.md|%SKILLS% skills"
  "ONBOARDING.md|%COMMANDS% slash commands"
  "ONBOARDING.md|%RULES% canonical mini-rules"
)

check_drift() {
  local skills commands rules
  skills="$(count_skills)"
  commands="$(count_commands)"
  rules="$(count_rules)"

  local drift=0
  local entry file template pattern
  for entry in "${PATTERNS[@]}"; do
    file="${entry%%|*}"
    template="${entry#*|}"
    pattern="$template"
    pattern="${pattern//%SKILLS%/$skills}"
    pattern="${pattern//%COMMANDS%/$commands}"
    pattern="${pattern//%RULES%/$rules}"

    if [ ! -f "$AIKIT/$file" ]; then
      continue
    fi

    if ! grep -qF "$pattern" "$AIKIT/$file"; then
      echo "DRIFT: $file expected to contain '$pattern'"
      # Surface the nearest stale match so the fix is obvious.
      local stale_template stale_re
      stale_template="$template"
      # Escape ERE metacharacters before the placeholders become `[0-9]+`,
      # otherwise a literal `|` or `(` in the template reads as regex syntax.
      stale_re="$(printf '%s' "$stale_template" | sed 's/[][\.^$*+?(){}|]/\\&/g')"
      stale_re="${stale_re//%SKILLS%/[0-9]+}"
      stale_re="${stale_re//%COMMANDS%/[0-9]+}"
      stale_re="${stale_re//%RULES%/[0-9]+}"
      grep -nE "$stale_re" "$AIKIT/$file" 2>/dev/null | head -2 | sed 's/^/  found: /'
      drift=$((drift + 1))
    fi
  done

  if [ "$drift" -gt 0 ]; then
    echo ""
    echo "Canonical counts: skills=$skills commands=$commands rules=$rules"
    echo "Fix the lines above OR run bin/count-primitives.sh --check after every release."
    return 1
  fi

  echo "OK — all tracked surfaces carry the canonical counts (skills=$skills commands=$commands rules=$rules)."
  return 0
}

case "${1:-}" in
  --human) emit_human ;;
  --check) check_drift ;;
  ""|--json) emit_json ;;
  -h|--help)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "Unknown arg: $1" >&2
    exit 2
    ;;
esac
