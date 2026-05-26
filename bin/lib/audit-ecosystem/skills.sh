# shellcheck shell=bash
# User-scope skills surface walk for ai-kit-audit-ecosystem.sh.
# REPLACE when shadowing a plugin skill, else KEEP-EXTERNAL.

walk_skills() {
  want_scope skills || return 0
  [ -d "$USER_SKILLS_DIR" ] || return 0

  local skill_path name
  for skill_path in "$USER_SKILLS_DIR"/*/; do
    [ -d "$skill_path" ] || continue
    name="$(basename "$skill_path")"
    if [ -d "$PLUGIN_SKILLS_DIR/$name" ]; then
      emit skills "$name" "REPLACE" \
        "ai-kit ships skills/$name — personal copy shadows the plugin version" \
        "user_path=$skill_path"
    else
      emit skills "$name" "KEEP-EXTERNAL" \
        "user-scope skill not owned by ai-kit" \
        "user_path=$skill_path"
    fi
  done
}
