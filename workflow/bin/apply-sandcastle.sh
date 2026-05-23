#!/usr/bin/env bash
# Install Sandcastle scaffold for AFK agents (stack-agnostic).
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/detect-package-manager.sh
source "$AIKIT/bin/lib/detect-package-manager.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/project"
  exit 1
fi

TARGET="$(cd "$1" && pwd)"
SC="$TARGET/.sandcastle"

mkdir -p "$SC"

cp -n "$AIKIT/orchestration/sandcastle/sequential-reviewer/"* "$SC/" 2>/dev/null || true
cp -n "$AIKIT/orchestration/sandcastle/prompt.md.template" "$SC/prompt.md" 2>/dev/null || true
cp "$AIKIT/orchestration/sandcastle/main.ts.template" "$SC/main.mts"

detect_package_manager "$TARGET"

INSTALL="${INSTALL_CMD:-echo 'No lockfile detected — configure install hook in main.mts'}"
if [ "$COPY_NODE_MODULES" = true ]; then
  COPY_JSON='["node_modules"]'
else
  COPY_JSON="[]"
fi

# Patch placeholders in main.mts
tmp="$(mktemp)"
sed "s|{{INSTALL_CMD}}|${INSTALL}|g" "$SC/main.mts" | sed "s|{{COPY_TO_WORKTREE}}|${COPY_JSON}|g" > "$tmp"
mv "$tmp" "$SC/main.mts"

echo "Sandcastle scaffold installed at .sandcastle/"
echo "Install hook: ${INSTALL}"
echo "Next: install @ai-hero/sandcastle per project docs, then run sandcastle init"
echo "Note: Sandcastle AFK agents need Docker Desktop running."
