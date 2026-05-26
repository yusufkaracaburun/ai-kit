# shellcheck shell=bash
# Shared state + helpers for bin/ai-kit-audit-ecosystem.sh surface walks.
#
# Sourced (never executed) by the dispatcher AFTER it has set:
#   HOME_DIR             — host root (default $HOME, --home override)
#   CATALOG_ROOT         — ai-kit catalog root
#   CATALOG_PRIMITIVES   — workflow/ root inside catalog
#   SCOPE_FILTER         — all | plugins | marketplaces | skills | agents | rules | mcp
#   SELF_PLUGIN_NAME     — ai-kit's own plugin name (for self-reference handling)
#
# Provides:
#   RECORDS              — append-only array of TSV (SEP-delimited) finding rows
#   SEP                  — record separator (0x1f)
#   emit                 — append a finding row to RECORDS
#   want_scope           — true when SCOPE_FILTER matches the surface (or "all")
#   parse_rec            — split a record into rec_surface/name/verdict/reason/detail
#
# Surface-walk libs (plugins.sh, marketplaces.sh, …) export one function each
# (walk_<surface>) and assume `common.sh` has already been sourced.

SEP=$'\x1f'
RECORDS=()

emit() {
  local surface="$1" name="$2" verdict="$3" reason="$4" detail="${5:-}"
  RECORDS+=("${surface}${SEP}${name}${SEP}${verdict}${SEP}${reason}${SEP}${detail}")
}

want_scope() {
  [ "$SCOPE_FILTER" = "all" ] || [ "$SCOPE_FILTER" = "$1" ]
}

parse_rec() {
  local raw="$1"
  IFS="$SEP" read -r rec_surface rec_name rec_verdict rec_reason rec_detail <<< "$raw"
}

# Host paths (set after HOME_DIR is known).
INSTALLED_PLUGINS="$HOME_DIR/.claude/plugins/installed_plugins.json"
KNOWN_MARKETPLACES="$HOME_DIR/.claude/plugins/known_marketplaces.json"
USER_SKILLS_DIR="$HOME_DIR/.claude/skills"
USER_AGENTS_DIR="$HOME_DIR/.claude/agents"
USER_RULES_DIR="$HOME_DIR/.claude/rules"
USER_SETTINGS="$HOME_DIR/.claude/settings.json"

# Catalog paths.
PLUGINS_CATALOG="$CATALOG_ROOT/standards/external/plugins.json"
PLUGINS_EXCLUDED="$CATALOG_ROOT/standards/external/plugins-excluded.json"
MCP_CATALOG="$CATALOG_ROOT/standards/external/mcp-servers.json"
PLUGIN_SKILLS_DIR="$CATALOG_PRIMITIVES/skills"
PLUGIN_AGENTS_DIR="$CATALOG_PRIMITIVES/agents"
PLUGIN_RULES_DIR="$CATALOG_ROOT/standards/rules"
