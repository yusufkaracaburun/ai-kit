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

# Symlink $src -> $dest, but never clobber a same-named custom entry —
# `ln -sfn` nests a symlink INSIDE an existing real directory rather than
# replacing it, which breaks a custom skill/agent that happens to share an
# ai-kit entry's name. A real dir/file at $dest is always custom (skip it).
# A symlink at $dest is custom only if it resolves INSIDE the project tree
# ($project_root) — e.g. a project's own `.claude/skills/x -> ../../.agents/
# skills/x` cross-link. A symlink resolving outside the project (into some
# ai-kit install, any version) is ai-kit's own and safe to relink even when
# stale/dangling (a pre-plugin-current link into a since-GC'd version dir
# must still be repairable, not mistaken for custom just because it no
# longer resolves).
link_preserving_custom() {
  local src="$1" dest="$2" label="$3" project_root="$4"
  local custom=false
  if [ -L "$dest" ]; then
    local target resolved
    target="$(readlink "$dest")"
    case "$target" in
      /*) resolved="$target" ;;
      *) resolved="$(cd "$(dirname "$dest")/$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")" ;;
    esac
    case "$resolved" in "$project_root"/*) custom=true ;; esac
  elif [ -e "$dest" ]; then
    custom=true
  fi
  if [ "$custom" = true ]; then
    echo "Skipped $label/$(basename "$dest"): custom entry shares a name with an ai-kit entry, left untouched" >&2
    return 0
  fi
  ln -sfn "$src" "$dest"
}

merge_skills() {
  local dest_parent="$1" label="$2" primitives="$3"
  local skills_dir="$dest_parent/skills"
  local resolved aikit_resolved project_root

  mkdir -p "$dest_parent"
  project_root="$(cd "$dest_parent/.." && pwd -P)"

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
    link_preserving_custom "$skill" "$skills_dir/$(basename "$skill")" "$label" "$project_root"
  done
  echo "Merged ai-kit skills into $label (custom entries preserved)"
}

merge_agents() {
  local dest_parent="$1" label="$2" primitives="$3"
  local agents_dir="$dest_parent/agents"
  local src_root="$primitives/agents"
  local project_root legacy

  [ -d "$src_root" ] || return 0
  mkdir -p "$agents_dir"
  project_root="$(cd "$dest_parent/.." && pwd -P)"
  for agent in "$src_root"/*.md; do
    [ -f "$agent" ] || continue
    # Pre-2.2.1 linked a dir per agent, which Claude Code registers as <dir>:<name>.
    legacy="$agents_dir/$(basename "$agent" .md)"
    if [ -L "$legacy" ]; then
      case "$(readlink "$legacy")" in *ai-kit*|*plugins/cache/*) rm -f "$legacy" ;; esac
    fi
    link_preserving_custom "$agent" "$agents_dir/$(basename "$agent")" "$label" "$project_root"
  done
  echo "Merged ai-kit subagents into $label (custom entries preserved)"
}

merge_commands() {
  local dest_parent="$1" label="$2" primitives="$3"
  local commands_dir="$dest_parent/commands"
  local src_root="$primitives/commands"
  local project_root

  [ -d "$src_root" ] || return 0
  mkdir -p "$commands_dir"
  project_root="$(cd "$dest_parent/.." && pwd -P)"
  for cmd in "$src_root"/*.md; do
    [ -f "$cmd" ] || continue
    link_preserving_custom "$cmd" "$commands_dir/$(basename "$cmd")" "$label" "$project_root"
  done
  echo "Merged ai-kit slash commands into $label (custom entries preserved)"
}

# Symlink every subdirectory of $src_root into $target, refusing to clobber
# user/custom entries. Used for skills — each entry is a directory containing
# a SKILL.md.
install_dir_to() {
  local src_root="$1"
  local target="$2"
  local src_real
  if [ ! -d "$src_root" ]; then
    return 0
  fi
  src_real="$(cd "$src_root" && pwd -P)"
  mkdir -p "$target"
  # Reap ai-kit links whose target moved. Includes orphans this run will not
  # relink (renamed or removed entries), which would otherwise stay dead
  # forever — the loop below only ever visits names that still exist in the
  # source tree, and a dead link there reads as "existing entry, skip".
  for dead in "$target"/*; do
    [ -L "$dead" ] && [ ! -e "$dead" ] || continue
    was="$(readlink "$dead")"
    case "$was" in
      */ai-kit/*|"${PREV_ROOT:-//no-previous-root}"/*)
        rm -f "$dead"
        echo "Removed dead link $(basename "$dead") (was -> $was)"
        ;;
    esac
  done
  for entry in "$src_root"/*/; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    dest="$target/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        [ "$(readlink "$dest")" = "$entry" ] && continue
        resolved="$(cd "$dest" 2>/dev/null && pwd -P)" || resolved=""
        case "$resolved" in
          "$src_real"/*) rm -f "$dest" ;;
          *)
            echo "Skipped $name (existing non-aikit entry at $dest)"
            continue
            ;;
        esac
      else
        echo "Skipped $name (existing non-aikit entry at $dest)"
        continue
      fi
    fi
    ln -sfn "$entry" "$dest"
    echo "Linked $name -> $dest"
  done
}

# ~/.cursor/skills held ai-kit's links up to v2.10.1; Cursor also reads
# ~/.agents/skills, so they would show twice. Removes links into ai-kit
# (plugin, or $1's source tree); foreign entries stay. Needs ai-kit-root.sh.
prune_cursor_global_skills() {
  local src_real="" link resolved
  # Same dir (~/.cursor/skills -> ~/.agents/skills): pruning would delete the links just made.
  [ "$(cd "${HOME}/.cursor/skills" 2>/dev/null && pwd -P)" = "$(cd "${HOME}/.agents/skills" 2>/dev/null && pwd -P)" ] && return 0
  [ -n "${1:-}" ] && src_real="$(cd "$1" 2>/dev/null && pwd -P)"
  for link in "${HOME}/.cursor/skills"/*; do
    [ -L "$link" ] || continue
    resolved="$(cd "$link" 2>/dev/null && pwd -P)" || resolved=""
    if aikit_skill_link "$link" || { [ -n "$src_real" ] && [[ $resolved == "$src_real"/* ]]; }; then
      rm -f "$link"
    fi
  done
  return 0
}
