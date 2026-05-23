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
    cd "$script_bin_dir/.." && pwd
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

write_ai_kit_root_config() {
  local root="$1"
  mkdir -p "${HOME}/.config/ai-kit"
  printf '%s\n' "$(cd "$root" && pwd)" > "${HOME}/.config/ai-kit/root"
}
