#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== eval-structure enforces the skill↔agent pairing rule ==="
# An agent at workflow/agents/<x>.md ships only as some skill's delegate:
# every agent is named by ≥1 SKILL.md, every subagent_type=ai:<x> a skill names
# exists and carries the plugin namespace, and no kit agent pins model: —
# which model runs it is the consumer's choice.

EVAL="$AIKIT/tests/bin/eval-structure.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

mk_skill() {
  mkdir -p "$T/workflow/skills/$1"
  printf -- '---\nname: %s\ndescription: Use when testing the agent pairing rule in eval-structure.\n---\n\n%s\n' \
    "$1" "$2" > "$T/workflow/skills/$1/SKILL.md"
}
mk_agent() {
  mkdir -p "$T/workflow/agents"
  printf -- '---\nname: %s\ndescription: Fixture agent.\n%s---\n\nBody.\n' \
    "$1" "${2:-}" > "$T/workflow/agents/$1.md"
}

mk_skill paired   'Delegate via `subagent_type=ai:good`; deep passes use subagent_type=ai:pinned.'
mk_skill dangling 'Delegate via the Task tool with `subagent_type=ai:ghost`.'
mk_skill bare     'Delegate via `subagent_type=good`.'
mk_agent good
mk_agent orphan
mk_agent pinned $'model: sonnet\n'

OUT="$(AIKIT="$T" bash "$EVAL" 2>&1 || true)"
assert "paired agent passes" \
  'grep -q "OK: \[agent good\] referenced by" <<<"$OUT" && ! grep -q "FAIL: \[agent good\]" <<<"$OUT"'
assert "orphan agent reported" 'grep -q "FAIL: \[agent orphan\] orphan" <<<"$OUT"'
assert "dangling subagent_type reported" 'grep -q "FAIL: \[dangling\] .*ghost" <<<"$OUT"'
assert "unnamespaced subagent_type reported" 'grep -q "FAIL: \[bare\] .*ai:" <<<"$OUT"'
assert "model: pin reported" 'grep -q "FAIL: \[agent pinned\] .*model:" <<<"$OUT"'

print_summary_and_exit
