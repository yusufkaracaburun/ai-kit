# shellcheck shell=bash
# User-scope agents surface walk for ai-kit-audit-ecosystem.sh.
# REPLACE when shadowing a plugin agent, else KEEP-EXTERNAL.

walk_agents() {
  want_scope agents || return 0
  [ -d "$USER_AGENTS_DIR" ] || return 0

  local agent_file name
  for agent_file in "$USER_AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    name="$(basename "$agent_file" .md)"
    if [ -d "$PLUGIN_AGENTS_DIR/$name" ]; then
      emit agents "$name" "REPLACE" \
        "ai-kit ships agents/$name — personal copy shadows the plugin version" \
        "user_path=$agent_file"
    else
      emit agents "$name" "KEEP-EXTERNAL" \
        "user-scope agent not owned by ai-kit" \
        "user_path=$agent_file"
    fi
  done
}
