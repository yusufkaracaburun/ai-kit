#!/usr/bin/env bash
# Keep the bundled-in-plugin hook scripts byte-identical to their canonical
# source in bin/.
#
# Source-of-truth (single):
#   bin/hooks/post-skill-log.sh  — the PostToolUse hook script
#   bin/log-skill.sh             — the JSONL writer the hook delegates to
#
# Bundled copies (under workflow/, shipped with the Claude Code plugin):
#   workflow/hooks/post-skill-log.sh
#   workflow/hooks/log-skill.sh
#
# Why duplicate? The plugin install only ships the workflow/ subtree, so
# the hook must live there. We refuse to silently diverge — the same hook
# script must work from both layouts (`bin/hooks/` and `workflow/hooks/`),
# and this sync (+ --check in CI / release) guarantees no drift.
#
# Usage:
#   sync-plugin-hooks.sh          # stamp bundled copies from bin/
#   sync-plugin-hooks.sh --check  # exit 1 if any bundled copy drifted
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

# Source → bundled-destination pairs. Add another row to ship more files.
PAIRS=(
  "bin/hooks/post-skill-log.sh|workflow/hooks/post-skill-log.sh"
  "bin/log-skill.sh|workflow/hooks/log-skill.sh"
  "bin/hooks/session-rules-inject.sh|workflow/hooks/session-rules-inject.sh"
)

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help)
    sed -n '1,21p' "$0"
    exit 0
    ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

drift=0
for pair in "${PAIRS[@]}"; do
  src="$AIKIT/${pair%%|*}"
  dst="$AIKIT/${pair##*|}"

  if [ ! -f "$src" ]; then
    echo "Source missing: $src" >&2
    exit 2
  fi

  if [ "$MODE" = "check" ]; then
    if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
      echo "Drift: $dst differs from $src" >&2
      drift=1
    fi
    continue
  fi

  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    continue   # already in sync
  fi
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "Synced: $dst"
done

if [ "$MODE" = "check" ] && [ "$drift" -ne 0 ]; then
  echo "" >&2
  echo "Run bin/sync-plugin-hooks.sh to re-stamp." >&2
  exit 1
fi
