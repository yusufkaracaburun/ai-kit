# shellcheck shell=bash
# User-scope rules surface walk for ai-kit-audit-ecosystem.sh.
# OWNED when matching plugin rule stem OR universal MCP rule, else KEEP-EXTERNAL.

walk_rules() {
  want_scope rules || return 0
  [ -d "$USER_RULES_DIR" ] || return 0

  local PLUGIN_RULE_STEMS=() rule_file stem
  if [ -d "$PLUGIN_RULES_DIR" ]; then
    for rule_file in "$PLUGIN_RULES_DIR"/*.md "$PLUGIN_RULES_DIR"/feedback/*.md; do
      [ -f "$rule_file" ] || continue
      stem="$(basename "$rule_file")"
      stem="${stem%.mini.md}"
      stem="${stem%.nano.md}"
      stem="${stem%.md}"
      PLUGIN_RULE_STEMS+=("$stem")
    done
  fi

  local MCP_UNIVERSAL=() line
  if [ -f "$MCP_CATALOG" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && MCP_UNIVERSAL+=("$line")
    done < <(python3 - "$MCP_CATALOG" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for e in data.get("recommendations", []):
    if e.get("universal"):
        print(e.get("name", ""))
PY
    )
  fi

  local name found mcp
  for rule_file in "$USER_RULES_DIR"/*.md; do
    [ -f "$rule_file" ] || continue
    name="$(basename "$rule_file" .md)"
    found=0
    for stem in "${PLUGIN_RULE_STEMS[@]}"; do
      [ "$stem" = "$name" ] && { found=1; break; }
    done
    if [ "$found" -eq 0 ]; then
      for mcp in "${MCP_UNIVERSAL[@]}"; do
        [ "$mcp" = "$name" ] && { found=1; break; }
      done
    fi
    if [ "$found" -eq 1 ]; then
      emit rules "$name" "OWNED" \
        "rule covered by ai-kit catalog (canonical rule or universal MCP)" \
        "user_path=$rule_file"
    else
      emit rules "$name" "KEEP-EXTERNAL" \
        "user-scope rule not in ai-kit catalog" \
        "user_path=$rule_file"
    fi
  done
}
