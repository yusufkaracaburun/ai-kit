#!/usr/bin/env bash
# Stamp the plugin's global rules payload (ADR-0015): every `universal: true`
# + `default_mode: always-on` rule in standards/rules/, emitted in Claude
# Code form into workflow/rules/. The plugin's SessionStart hook
# (bin/hooks/global-rules-link.sh) links that directory at
# ~/.claude/rules/ai-kit, so the host loads the pathless ones every session
# and the `paths:`-scoped ones on touch — in every project on the machine,
# with no per-repo copies. On-demand universals stay out: nothing under
# ~/.claude/rules/ can be fenced, a pathless file there always loads.
#
# Usage:
#   sync-plugin-rules.sh          # stamp workflow/rules/ from standards/rules/
#   sync-plugin-rules.sh --check  # exit 1 if workflow/rules/ drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
# shellcheck source=lib/emitter-lib.sh
source "$SCRIPT_BIN/lib/emitter-lib.sh"
# shellcheck source=lib/emitters/claude-code.sh
source "$SCRIPT_BIN/lib/emitters/claude-code.sh"
# shellcheck source=lib/sync-mirror.sh
source "$SCRIPT_BIN/lib/sync-mirror.sh"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help) sed -n '1,13p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

RULES_DIR="$AIKIT/standards/rules"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

paths=()
for f in "$RULES_DIR"/*.mini.md "$RULES_DIR"/*.nano.md \
         "$RULES_DIR"/feedback/*.mini.md "$RULES_DIR"/feedback/*.nano.md; do
  [ -f "$f" ] || continue
  [ "$(_emitter_extract_meta "$f" universal)" = "true" ] || continue
  [ "$(_emitter_extract_meta "$f" default_mode)" = "always-on" ] || continue
  paths+=("$f")
done
names=("${paths[@]##*/}"); names=("${names[@]%.mini.md}"); names=("${names[@]%.nano.md}")

# Sibling links between global rules resolve inside ~/.claude/rules/ai-kit;
# links to anything else are unlinked (issue #105 rewrite in _emitter_body).
export AIKIT_EMITTED_RULES="${names[*]}"
for i in "${!paths[@]}"; do
  emit_claude_code_global "$TMP" "${paths[$i]}" "${names[$i]}"
done

sync_mirror "$TMP" "$AIKIT/workflow/rules" "$MODE" "bin/sync-plugin-rules.sh"
