#!/usr/bin/env bash
# Symlink ai-kit skills/agents/commands into a project, preserving any
# project-local custom entries. Shared by bootstrap-project.sh (initial
# install) and ai-kit-upgrade.sh (repair links after a version bump, #114) so
# both stay in lockstep with the plugin-current indirection.

# Whole-dir symlink: $dest_parent/skills -> $primitives/skills (or a copy).
# Used by --link-all (greenfield / explicit replace).
link_skills_all() {
  local dest_parent="$1" label="$2" primitives="$3" copy="${4:-false}"
  mkdir -p "$dest_parent"
  if [ "$copy" = true ]; then
    rm -rf "$dest_parent/skills"
    cp -R "$primitives/skills" "$dest_parent/skills"
    echo "Copied skills to $dest_parent/skills/"
  else
    ln -sfn "$primitives/skills" "$dest_parent/skills"
    echo "Symlinked $label -> ai-kit skills"
  fi
}

merge_skills() {
  local dest_parent="$1" label="$2" primitives="$3"
  local skills_dir="$dest_parent/skills"
  local resolved aikit_resolved

  mkdir -p "$dest_parent"

  if [ -L "$skills_dir" ]; then
    resolved="$(cd "$skills_dir" 2>/dev/null && pwd -P)" || resolved=""
    aikit_resolved="$(cd "$primitives/skills" && pwd -P)"
    if [ "$resolved" = "$aikit_resolved" ]; then
      echo "$label already linked to ai-kit skills"
      return 0
    fi
    rm -f "$skills_dir"
  fi

  mkdir -p "$skills_dir"
  for skill in "$primitives/skills"/*/; do
    [ -d "$skill" ] || continue
    ln -sfn "$skill" "$skills_dir/$(basename "$skill")"
  done
  echo "Merged ai-kit skills into $label (custom entries preserved)"
}

merge_agents() {
  local dest_parent="$1" label="$2" primitives="$3"
  local agents_dir="$dest_parent/agents"
  local src_root="$primitives/agents"

  [ -d "$src_root" ] || return 0
  mkdir -p "$agents_dir"
  for agent in "$src_root"/*/; do
    [ -d "$agent" ] || continue
    ln -sfn "$agent" "$agents_dir/$(basename "$agent")"
  done
  echo "Merged ai-kit subagents into $label (custom entries preserved)"
}

merge_commands() {
  local dest_parent="$1" label="$2" primitives="$3"
  local commands_dir="$dest_parent/commands"
  local src_root="$primitives/commands"

  [ -d "$src_root" ] || return 0
  mkdir -p "$commands_dir"
  for cmd in "$src_root"/*.md; do
    [ -f "$cmd" ] || continue
    ln -sfn "$cmd" "$commands_dir/$(basename "$cmd")"
  done
  echo "Merged ai-kit slash commands into $label (custom entries preserved)"
}
