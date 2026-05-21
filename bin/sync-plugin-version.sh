#!/usr/bin/env bash
# Re-stamp the plugin manifest and marketplace catalog with the current
# ai-kit VERSION. Idempotent; safe to run on every release.
#
# VERSION is the single source of truth. Three derived locations must
# stay in sync:
#   1. VERSION
#   2. workflow/.claude-plugin/plugin.json:version
#   3. .claude-plugin/marketplace.json:plugins[0].version
#
# Usage:
#   sync-plugin-version.sh           # stamp from VERSION
#   sync-plugin-version.sh --check   # verify equality, exit 1 on drift
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

VERSION_FILE="$AIKIT/VERSION"
PLUGIN_JSON="$AIKIT/workflow/.claude-plugin/plugin.json"
MARKET_JSON="$AIKIT/.claude-plugin/marketplace.json"

if [ ! -f "$VERSION_FILE" ]; then
  echo "VERSION file missing at $VERSION_FILE" >&2
  exit 2
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

MODE="stamp"
case "${1:-}" in
  --check) MODE="check" ;;
  -h|--help)
    sed -n '1,15p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
esac

# Extract current "version" value from a JSON file. Uses python3 (always
# available on macOS + most CI) to avoid a jq dependency.
extract_version() {
  local file="$1"
  local jq_path="$2"
  python3 -c "
import json,sys
with open('$file') as f:
    d = json.load(f)
parts = '$jq_path'.split('.')
obj = d
for p in parts:
    if p.endswith(']'):
        key, idx = p[:-1].split('[')
        obj = obj[key][int(idx)]
    else:
        obj = obj[p]
print(obj)
"
}

# Set the "version" value at $jq_path in a JSON file to $new_version.
set_version() {
  local file="$1"
  local jq_path="$2"
  local new_version="$3"
  python3 -c "
import json,sys
with open('$file') as f:
    d = json.load(f)
parts = '$jq_path'.split('.')
obj = d
for p in parts[:-1]:
    if p.endswith(']'):
        key, idx = p[:-1].split('[')
        obj = obj[key][int(idx)]
    else:
        obj = obj[p]
obj[parts[-1]] = '$new_version'
with open('$file','w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
}

CURRENT_PLUGIN="$(extract_version "$PLUGIN_JSON" "version")"
CURRENT_MARKET="$(extract_version "$MARKET_JSON" "plugins[0].version")"

case "$MODE" in
  check)
    DRIFT=0
    if [ "$VERSION" != "$CURRENT_PLUGIN" ]; then
      echo "DRIFT: VERSION=$VERSION but plugin.json:version=$CURRENT_PLUGIN" >&2
      DRIFT=1
    fi
    if [ "$VERSION" != "$CURRENT_MARKET" ]; then
      echo "DRIFT: VERSION=$VERSION but marketplace.json:plugins[0].version=$CURRENT_MARKET" >&2
      DRIFT=1
    fi
    if [ "$DRIFT" -eq 0 ]; then
      echo "OK: VERSION/plugin.json/marketplace.json all at $VERSION"
    fi
    exit "$DRIFT"
    ;;
  stamp)
    if [ "$VERSION" = "$CURRENT_PLUGIN" ] && [ "$VERSION" = "$CURRENT_MARKET" ]; then
      echo "Already at $VERSION (no changes)"
      exit 0
    fi
    set_version "$PLUGIN_JSON" "version" "$VERSION"
    set_version "$MARKET_JSON" "plugins[0].version" "$VERSION"
    echo "Stamped $VERSION into:"
    echo "  $PLUGIN_JSON"
    echo "  $MARKET_JSON"
    ;;
esac
