#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

COPY_SKILLS=false
MINIMAL=true
NO_SKILLS=false
SKILLS_MODE="merge-skills"
WITH_MCP=false

usage() {
  echo "Usage: $0 [--minimal] /path/to/project [options]"
  echo ""
  echo "Options:"
  echo "  --minimal       Install ai-kit skeleton only (default)"
  echo "  --merge-skills  Symlink ai-kit skills individually (default; preserves custom skills)"
  echo "  --link-all      Symlink entire skills dir to ai-kit (greenfield / explicit replace)"
  echo "  --copy-skills   Copy skills into project instead of symlink"
  echo "  --no-skills     Skip .agents/skills and .cursor/skills (use global install only)"
  echo "  --with-mcp      Copy baseline .cursor/mcp.json.template to .cursor/mcp.json (opt-in)"
  echo ""
  echo "Configures Claude Code (.agents/skills) and Cursor (.cursor/skills)."
  echo "Full setup via /setup in the agent."
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
    --with-mcp) WITH_MCP=true; shift ;;
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

link_skills_all() {
  local dest_parent="$1"
  local label="$2"
  mkdir -p "$dest_parent"
  if [ "$COPY_SKILLS" = true ]; then
    rm -rf "$dest_parent/skills"
    cp -R "$AIKIT/workflow/skills" "$dest_parent/skills"
    echo "Copied workflow skills to $dest_parent/skills/"
  else
    ln -sfn "$AIKIT/workflow/skills" "$dest_parent/skills"
    echo "Symlinked $label -> ai-kit workflow/skills"
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
    aikit_resolved="$(cd "$AIKIT/workflow/skills" && pwd -P)"
    if [ "$resolved" = "$aikit_resolved" ]; then
      echo "$label already linked to ai-kit workflow/skills"
      return 0
    fi
    rm -f "$skills_dir"
  fi

  mkdir -p "$skills_dir"
  for skill in "$AIKIT/workflow/skills"/*/; do
    [ -d "$skill" ] || continue
    ln -sfn "$skill" "$skills_dir/$(basename "$skill")"
  done
  echo "Merged ai-kit skills into $label (custom entries preserved)"
}

if [ "$NO_SKILLS" = true ]; then
  echo "Skipped project skill links (--no-skills; use global ~/.agents/skills and ~/.cursor/skills)"
elif [ "$SKILLS_MODE" = "link-all" ]; then
  link_skills_all "$TARGET/.agents" ".agents/skills"
  link_skills_all "$TARGET/.cursor" ".cursor/skills"
else
  merge_skills "$TARGET/.agents" ".agents/skills"
  merge_skills "$TARGET/.cursor" ".cursor/skills"
fi

mkdir -p "$TARGET/.cursor/rules"

if [ ! -f "$TARGET/.cursor/rules/ai-kit.mdc" ]; then
  cp "$TPL/.cursor/rules/ai-kit.mdc" "$TARGET/.cursor/rules/ai-kit.mdc"
  echo "Created .cursor/rules/ai-kit.mdc"
fi

if [ "$WITH_MCP" = true ]; then
  if [ -f "$TARGET/.cursor/mcp.json" ] || [ -f "$TARGET/.mcp.json" ] || [ -f "$TARGET/.vscode/mcp.json" ]; then
    echo "Skipped mcp.json copy (existing MCP config detected)"
  elif [ -f "$TPL/.cursor/mcp.json.template" ]; then
    cp "$TPL/.cursor/mcp.json.template" "$TARGET/.cursor/mcp.json"
    echo "Created .cursor/mcp.json (baseline — uncomment servers you want)"
  fi
fi

rule_to_mdc() {
  local src="$1" name="$2" desc="$3"
  local dest="$TARGET/.cursor/rules/${name}.mdc"
  [ -f "$dest" ] && return 0
  cat > "$dest" << EOF
---
description: ${desc}
globs:
alwaysApply: false
---

$(cat "$src")
EOF
  echo "Created .cursor/rules/${name}.mdc"
}

rule_to_mdc "$AIKIT/standards/rules/legacy-code.mini.md" "legacy-code" "Working Effectively with Legacy Code rules"
rule_to_mdc "$AIKIT/standards/rules/ddd-distilled.mini.md" "ddd-distilled" "DDD Distilled rules"
rule_to_mdc "$AIKIT/standards/rules/refactoring.mini.md" "refactoring" "Refactoring rules"
rule_to_mdc "$AIKIT/standards/rules/aposd.mini.md" "aposd" "A Philosophy of Software Design rules"
rule_to_mdc "$AIKIT/standards/rules/release-it.mini.md" "release-it" "Release It production rules"

if [ ! -f "$TARGET/.cursor/rules/pragmatic-baseline.mdc" ]; then
  cat > "$TARGET/.cursor/rules/pragmatic-baseline.mdc" << EOF
---
description: Pragmatic Programmer baseline (optional always-on)
globs:
alwaysApply: false
---

$(cat "$AIKIT/standards/rules/pragmatic.nano.md")
EOF
  echo "Created .cursor/rules/pragmatic-baseline.mdc"
fi

echo ""
echo "Bootstrap complete: $TARGET"
echo "Run /setup to configure dev environment, Docker, tracker, and agile workflow."
