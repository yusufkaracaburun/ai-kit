#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

COPY_SKILLS=false
MINIMAL=true
NO_SKILLS=false
NO_AGENTS=false
NO_COMMANDS=false
SKILLS_MODE="merge-skills"
WITH_MCP=false
EMIT_RULES=true
SETUP_GH_WORKFLOW=true
GH_WORKFLOW_LANG="nl"

usage() {
  echo "Usage: $0 [--minimal] /path/to/project [options]"
  echo ""
  echo "Options:"
  echo "  --minimal       Install ai-kit skeleton only (default)"
  echo "  --merge-skills  Symlink ai-kit skills individually (default; preserves custom skills)"
  echo "  --link-all      Symlink entire skills dir to ai-kit (greenfield / explicit replace)"
  echo "  --copy-skills   Copy skills into project instead of symlink"
  echo "  --no-skills     Skip .agents/skills, .claude/skills and .cursor/skills (use global install only)"
  echo "  --no-agents     Skip .claude/agents (Claude Code subagents)"
  echo "  --no-commands   Skip .claude/commands and .cursor/commands (slash commands)"
  echo "  --with-mcp      Copy baseline .cursor/mcp.json.template to .cursor/mcp.json (opt-in)"
  echo "  --no-rules      Skip emit-rules.sh (no universal canonical rules in this project)"
  echo "  --no-gh-workflow  Skip GH workflow setup (issue templates + DoR/DoD enforcement + auto-promote)"
  echo "  --gh-lang=en|nl Language for issue templates (default: nl)"
  echo ""
  echo "Configures Claude Code (.claude/skills + legacy .agents/skills) and Cursor (.cursor/skills)."
  echo "Full setup via /ai:setup in the agent."
  exit 1
}

TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --minimal) MINIMAL=true; shift ;;
    --merge-skills) SKILLS_MODE="merge-skills"; shift ;;
    --link-all) SKILLS_MODE="link-all"; shift ;;
    --copy-skills) COPY_SKILLS=true; SKILLS_MODE="link-all"; shift ;;
    --no-skills) NO_SKILLS=true; shift ;;
    --no-agents) NO_AGENTS=true; shift ;;
    --no-commands) NO_COMMANDS=true; shift ;;
    --with-mcp) WITH_MCP=true; shift ;;
    --no-rules) EMIT_RULES=false; shift ;;
    --no-gh-workflow) SETUP_GH_WORKFLOW=false; shift ;;
    --gh-lang=*) GH_WORKFLOW_LANG="${1#*=}"; shift ;;
    --gh-lang) GH_WORKFLOW_LANG="$2"; shift 2 ;;
    -h | --help) usage ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      if [ -n "$TARGET" ]; then
        echo "Unexpected argument: $1" >&2
        usage
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  usage
fi

if [ ! -d "$TARGET" ]; then
  echo "Creating $TARGET"
  mkdir -p "$TARGET"
fi

TARGET="$(cd "$TARGET" && pwd)"
TPL="$AIKIT/context/templates"

if [ ! -f "$TARGET/AGENTS.md" ]; then
  cp "$TPL/AGENTS.md.template" "$TARGET/AGENTS.md"
  echo "Created AGENTS.md"
fi

if [ ! -f "$TARGET/CONTEXT.md" ]; then
  cp "$TPL/CONTEXT.md.template" "$TARGET/CONTEXT.md"
  echo "Created CONTEXT.md"
fi

if [ ! -f "$TARGET/CLAUDE.md" ]; then
  cp "$TPL/CLAUDE.md.template" "$TARGET/CLAUDE.md"
  echo "Created CLAUDE.md"
fi

mkdir -p "$TARGET/docs/agents" "$TARGET/docs/adr" "$TARGET/docs/wiki"
cp -n "$TPL/docs/adr/ADR-template.md" "$TARGET/docs/adr/" 2>/dev/null || true
cp -n "$TPL/docs/wiki/README.md" "$TARGET/docs/wiki/" 2>/dev/null || true
# Agile workflow + triage-label mapping. verify-setup.sh checks both; without
# this copy they were verified but never produced. /ai:setup branch 9 fills in
# the framework section, branch 5 edits the label mapping.
cp -n "$TPL/docs/agents/workflow.md" "$TARGET/docs/agents/" 2>/dev/null || true
cp -n "$TPL/docs/agents/triage-labels.md" "$TARGET/docs/agents/" 2>/dev/null || true

link_skills_all() {
  local dest_parent="$1"
  local label="$2"
  mkdir -p "$dest_parent"
  if [ "$COPY_SKILLS" = true ]; then
    rm -rf "$dest_parent/skills"
    cp -R "$PRIMITIVES/skills" "$dest_parent/skills"
    echo "Copied skills to $dest_parent/skills/"
  else
    ln -sfn "$PRIMITIVES/skills" "$dest_parent/skills"
    echo "Symlinked $label -> ai-kit skills"
  fi
}

merge_skills() {
  local dest_parent="$1"
  local label="$2"
  local skills_dir="$dest_parent/skills"
  local resolved aikit_resolved

  mkdir -p "$dest_parent"

  if [ -L "$skills_dir" ]; then
    resolved="$(cd "$skills_dir" 2>/dev/null && pwd -P)" || resolved=""
    aikit_resolved="$(cd "$PRIMITIVES/skills" && pwd -P)"
    if [ "$resolved" = "$aikit_resolved" ]; then
      echo "$label already linked to ai-kit skills"
      return 0
    fi
    rm -f "$skills_dir"
  fi

  mkdir -p "$skills_dir"
  for skill in "$PRIMITIVES/skills"/*/; do
    [ -d "$skill" ] || continue
    ln -sfn "$skill" "$skills_dir/$(basename "$skill")"
  done
  echo "Merged ai-kit skills into $label (custom entries preserved)"
}

merge_agents() {
  local dest_parent="$1"
  local label="$2"
  local agents_dir="$dest_parent/agents"
  local src_root="$PRIMITIVES/agents"

  [ -d "$src_root" ] || return 0
  mkdir -p "$agents_dir"
  for agent in "$src_root"/*/; do
    [ -d "$agent" ] || continue
    ln -sfn "$agent" "$agents_dir/$(basename "$agent")"
  done
  echo "Merged ai-kit subagents into $label (custom entries preserved)"
}

merge_commands() {
  local dest_parent="$1"
  local label="$2"
  local commands_dir="$dest_parent/commands"
  local src_root="$PRIMITIVES/commands"

  [ -d "$src_root" ] || return 0
  mkdir -p "$commands_dir"
  for cmd in "$src_root"/*.md; do
    [ -f "$cmd" ] || continue
    ln -sfn "$cmd" "$commands_dir/$(basename "$cmd")"
  done
  echo "Merged ai-kit slash commands into $label (custom entries preserved)"
}

if [ "$NO_SKILLS" = true ]; then
  echo "Skipped project skill links (--no-skills; use global ~/.claude/skills, ~/.agents/skills and ~/.cursor/skills)"
elif [ "$SKILLS_MODE" = "link-all" ]; then
  link_skills_all "$TARGET/.claude" ".claude/skills"
  link_skills_all "$TARGET/.agents" ".agents/skills"
  link_skills_all "$TARGET/.cursor" ".cursor/skills"
else
  merge_skills "$TARGET/.claude" ".claude/skills"
  merge_skills "$TARGET/.agents" ".agents/skills"
  merge_skills "$TARGET/.cursor" ".cursor/skills"
fi

if [ "$NO_AGENTS" = true ]; then
  echo "Skipped project subagent links (--no-agents)"
else
  merge_agents "$TARGET/.claude" ".claude/agents"
fi

if [ "$NO_COMMANDS" = true ]; then
  echo "Skipped project slash command links (--no-commands)"
else
  merge_commands "$TARGET/.claude" ".claude/commands"
  merge_commands "$TARGET/.cursor" ".cursor/commands"
fi

if [ "$WITH_MCP" = true ]; then
  if [ -f "$TARGET/.cursor/mcp.json" ] || [ -f "$TARGET/.mcp.json" ] || [ -f "$TARGET/.vscode/mcp.json" ]; then
    echo "Skipped mcp.json copy (existing MCP config detected)"
  elif [ -f "$TPL/.cursor/mcp.json.template" ]; then
    cp "$TPL/.cursor/mcp.json.template" "$TARGET/.cursor/mcp.json"
    echo "Created .cursor/mcp.json (baseline — uncomment servers you want)"
  fi
fi

if [ "$EMIT_RULES" = true ]; then
  echo ""
  "$AIKIT/bin/emit-rules.sh" "$TARGET" || echo "warn: emit-rules.sh failed (non-fatal)"
fi

# Tier-A: GH workflow hygiene (issue templates + DoR/DoD enforcement +
# auto-promote-to-Ready). The script silent-skips on non-GitHub remotes,
# so it is safe to call unconditionally. Opt-out via --no-gh-workflow.
if [ "$SETUP_GH_WORKFLOW" = true ]; then
  echo ""
  "$AIKIT/bin/setup-gh-workflow.sh" "$TARGET" --lang "$GH_WORKFLOW_LANG" --quiet \
    || echo "warn: setup-gh-workflow.sh failed (non-fatal)"
fi

echo ""
echo "Bootstrap complete: $TARGET"
echo "Run /ai:setup to configure dev environment, Docker, tracker, and agile workflow."
