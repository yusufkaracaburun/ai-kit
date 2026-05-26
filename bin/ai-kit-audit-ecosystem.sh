#!/usr/bin/env bash
# Audit broader Claude Code primitive state on the host machine and emit a
# verdict per item against ai-kit's catalogs. Read-only: never modifies state.
# --converge prints a migration recipe but does not execute it.
#
# Surfaces:
#   plugins      — ~/.claude/plugins/installed_plugins.json entries
#   marketplaces — ~/.claude/plugins/known_marketplaces.json entries
#   skills       — ~/.claude/skills/*
#   agents       — ~/.claude/agents/*.md
#   rules        — ~/.claude/rules/*.md
#   mcp          — mcpServers block in ~/.claude/settings.json
#
# Verdicts:
#   OWNED          — ai-kit catalog already includes this; nothing to do
#   ADOPT          — present on machine, not catalogued → promotion candidate
#   REBIND         — scope mismatch (project-scoped where user-scope makes
#                    sense) or duplicate marketplace install
#   REPLACE        — ai-kit ships a functional equivalent
#   DROP-STALE     — references a path that no longer exists on disk
#   KEEP-EXTERNAL  — valid, out of ai-kit scope
#
# Note: -e and -u are intentionally omitted — this is a warning-collector
# that walks six surfaces (plugins, marketplaces, skills, agents, rules, mcp)
# even when one surface's catalog file is missing. Per-surface failures
# degrade to a verdict tag, never to a script abort. Strict `-u` would
# break the conditional-unbound-var pattern used across the surfaces.
#
# Per-surface logic lives in bin/lib/audit-ecosystem/<surface>.sh — this
# dispatcher only handles argument parsing, catalog/self detection, and
# the call sequence (walk → render → exit).
set -o pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

usage() {
  cat <<USAGE
Usage: $0 [--json] [--scope SCOPE] [--converge] [--strict] [--home DIR] [--catalog-root DIR]

Audit host Claude Code primitive state (installed plugins, user-scope skills/
agents/rules, MCP servers) against ai-kit catalogs. Emit per-item verdicts:
OWNED, ADOPT, REBIND, REPLACE, EXCLUDED, DROP-STALE, KEEP-EXTERNAL.

Options:
  --json              Machine-readable output.
  --scope SCOPE       Limit to one surface (plugins|marketplaces|skills|
                      agents|rules|mcp|all). Default: all.
  --converge          Print executable migration recipe (does NOT execute).
  --strict            Exit 1 when divergent findings are present (for CI).
                      Default is exit 0 always — this script is report-
                      only, and a non-zero exit confuses tooling that
                      treats it as failure.
  --home DIR          Override host root (default: \$HOME). Tests inject
                      fixture trees this way.
  --catalog-root DIR  Override ai-kit catalog root (default: resolved
                      AI_KIT_ROOT). Tests use this for synthetic catalogs.
  -h, --help          Show this message.

Exit codes:
  0  ran successfully (with or without divergent findings)
  1  divergent findings present AND --strict was passed
  2  usage error
USAGE
}

MODE_JSON=0
MODE_CONVERGE=0
MODE_STRICT=0
SCOPE_FILTER="all"
HOME_DIR="$HOME"
CATALOG_ROOT="$AIKIT"
CATALOG_PRIMITIVES="$PRIMITIVES"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) MODE_JSON=1; shift ;;
    --converge) MODE_CONVERGE=1; shift ;;
    --strict) MODE_STRICT=1; shift ;;
    --scope)
      [ -n "${2:-}" ] || { echo "--scope requires value" >&2; exit 2; }
      SCOPE_FILTER="$2"; shift 2 ;;
    --home)
      [ -n "${2:-}" ] || { echo "--home requires value" >&2; exit 2; }
      HOME_DIR="$2"; shift 2 ;;
    --catalog-root)
      [ -n "${2:-}" ] || { echo "--catalog-root requires value" >&2; exit 2; }
      CATALOG_ROOT="$2"
      CATALOG_PRIMITIVES="$(resolve_primitives_root "$CATALOG_ROOT")"
      shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

case "$SCOPE_FILTER" in
  all|plugins|marketplaces|skills|agents|rules|mcp) ;;
  *) echo "Invalid --scope: $SCOPE_FILTER" >&2; exit 2 ;;
esac

# Self-reference: the audit must never flag ai-kit's own plugin as an ADOPT
# candidate (you can't ship yourself in your own catalog).
SELF_PLUGIN_NAME=""
for self_manifest in "$CATALOG_ROOT/workflow/.claude-plugin/plugin.json" "$CATALOG_ROOT/.claude-plugin/plugin.json"; do
  if [ -f "$self_manifest" ]; then
    SELF_PLUGIN_NAME="$(python3 -c "
import json, sys
try:
    print(json.load(open('$self_manifest')).get('name', ''))
except Exception:
    pass
" 2>/dev/null)"
    [ -n "$SELF_PLUGIN_NAME" ] && break
  fi
done

# Source the surface walkers + renderers. Order matters: common.sh first
# (sets up RECORDS + helpers); render.sh last (depends on RECORDS).
LIBDIR="$SCRIPT_BIN/lib/audit-ecosystem"
# shellcheck source=lib/audit-ecosystem/common.sh
source "$LIBDIR/common.sh"
# shellcheck source=lib/audit-ecosystem/plugins.sh
source "$LIBDIR/plugins.sh"
# shellcheck source=lib/audit-ecosystem/marketplaces.sh
source "$LIBDIR/marketplaces.sh"
# shellcheck source=lib/audit-ecosystem/skills.sh
source "$LIBDIR/skills.sh"
# shellcheck source=lib/audit-ecosystem/agents.sh
source "$LIBDIR/agents.sh"
# shellcheck source=lib/audit-ecosystem/rules.sh
source "$LIBDIR/rules.sh"
# shellcheck source=lib/audit-ecosystem/mcp.sh
source "$LIBDIR/mcp.sh"
# shellcheck source=lib/audit-ecosystem/render.sh
source "$LIBDIR/render.sh"

# Walk each surface (each is a no-op when SCOPE_FILTER excludes it).
walk_plugins
walk_marketplaces
walk_skills
walk_agents
walk_rules
walk_mcp

DIVERGENT="$(count_divergent)"

if [ "$MODE_JSON" -eq 1 ]; then
  render_json
  if [ "$MODE_STRICT" -eq 1 ] && [ "$DIVERGENT" -gt 0 ]; then exit 1; else exit 0; fi
fi

render_text

if [ "$MODE_CONVERGE" -eq 1 ] && [ "$DIVERGENT" -gt 0 ]; then
  render_converge
fi

if [ "$DIVERGENT" -gt 0 ]; then
  echo "Found $DIVERGENT divergent item(s). Run with --converge to see migration recipe."
  if [ "$MODE_STRICT" -eq 1 ]; then exit 1; fi
  exit 0
else
  echo "Converged — host primitives match ai-kit catalog (or are explicitly external)."
  exit 0
fi
