#!/usr/bin/env bash
# Resolve ai-kit installation root.
# Priority: AI_KIT_ROOT env → script location (bin/..) → ~/.config/ai-kit/root
#
# Script-location beats the global config file: when a bin/ script knows its
# own path, that authoritative — otherwise running `bash bin/foo.sh` in a dev
# clone resolves to the global install and silently uses the wrong libraries.

resolve_ai_kit_root() {
  local script_bin_dir="${1:-}"

  if [ -n "${AI_KIT_ROOT:-}" ] && [ -d "$AI_KIT_ROOT" ]; then
    cd "$AI_KIT_ROOT" && pwd
    return 0
  fi

  if [ -n "$script_bin_dir" ] && [ -d "$script_bin_dir" ]; then
    local resolved
    resolved="$(cd "$script_bin_dir/.." && pwd)"
    sync_plugin_current_link "$resolved"
    echo "$resolved"
    return 0
  fi

  local config="${HOME}/.config/ai-kit/root"
  if [ -f "$config" ]; then
    local from_config
    from_config="$(tr -d '[:space:]' < "$config")"
    if [ -n "$from_config" ] && [ -d "$from_config" ]; then
      cd "$from_config" && pwd
      return 0
    fi
  fi

  echo "ai-kit root not found. Set AI_KIT_ROOT or run install-global.sh" >&2
  return 1
}

# The plugin cache path carries the ai-kit version (.../ai/1.43.1), so a
# `/plugin update` deletes it and orphans every project symlink bootstrap
# pointed there directly (#114). Refresh a stable indirection symlink on
# every plugin-mode resolution instead — bootstrap-project.sh links project
# skills/agents/commands through it, so the next ai-kit invocation after an
# update repoints one symlink and heals every project, with no project-side
# action required.
sync_plugin_current_link() {
  local resolved_root="$1"
  case "$resolved_root" in
    */plugins/cache/*)
      local link="${HOME}/.config/ai-kit/plugin-current"
      mkdir -p "$(dirname "$link")"
      ln -sfn "$resolved_root" "$link"
      ;;
  esac
}

write_ai_kit_root_config() {
  local root="$1"
  mkdir -p "${HOME}/.config/ai-kit"
  printf '%s\n' "$(cd "$root" && pwd)" > "${HOME}/.config/ai-kit/root"
}

# Where do skills/, agents/, commands/, hooks/ live?
# Dev clone: $AIKIT/workflow/<dir>
# Plugin install: $AIKIT/<dir>  (the workflow/ subdir IS the plugin root)
resolve_primitives_root() {
  local root="$1"
  if [ -d "$root/workflow/skills" ]; then
    echo "$root/workflow"
  else
    echo "$root"
  fi
}

# Read ai-kit version from VERSION (dev clone) or plugin.json (plugin install).
resolve_ai_kit_version() {
  local root="$1"
  if [ -f "$root/VERSION" ]; then
    tr -d '[:space:]' < "$root/VERSION"
  elif [ -f "$root/.claude-plugin/plugin.json" ]; then
    python3 -c "import json; print(json.load(open('$root/.claude-plugin/plugin.json'))['version'])"
  else
    echo "unknown"
  fi
}
