# shellcheck shell=bash
# MCP servers surface walk for ai-kit-audit-ecosystem.sh.

walk_mcp() {
  want_scope mcp || return 0
  [ -f "$USER_SETTINGS" ] || return 0

  local MCP_ROWS
  MCP_ROWS="$(python3 - "$USER_SETTINGS" "$MCP_CATALOG" <<'PY'
import json, sys, os
SEP = "\x1f"
settings = json.load(open(sys.argv[1]))
mcp = settings.get("mcpServers") or {}
catalog_path = sys.argv[2]
catalog = set()
if os.path.exists(catalog_path):
    for e in json.load(open(catalog_path)).get("recommendations", []):
        if e.get("name"):
            catalog.add(e["name"])
for name, meta in mcp.items():
    transport = meta.get("type") or ("stdio" if "command" in meta else "?")
    catalogued = "yes" if name in catalog else "no"
    print(f"{name}{SEP}{transport}{SEP}{catalogued}")
PY
  )"

  local name transport catalogued detail
  while IFS="$SEP" read -r name transport catalogued; do
    [ -n "$name" ] || continue
    detail="transport=$transport"
    if [ "$catalogued" = "yes" ]; then
      emit mcp "$name" "OWNED" "in standards/external/mcp-servers.json" "$detail"
    else
      emit mcp "$name" "ADOPT" "MCP server installed user-scope but not catalogued" "$detail"
    fi
  done <<< "$MCP_ROWS"
}
