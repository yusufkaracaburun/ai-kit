#!/usr/bin/env bash
# Scan for ai-kit duplication: personal skills/agents shadowing plugin assets,
# orphan emitted rules, and stale plugin-bin overlap. Reports findings only —
# never deletes. Exit 0 = no dups; 1 = dups found.
set -o pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<USAGE
Usage: $0 [path] [--json] [--fix]

Scan for ai-kit duplication across four surfaces:
  1. Personal skills (~/.claude/skills/) shadowing plugin skills
  2. Personal agents (~/.claude/agents/) shadowing plugin agents
  3. Orphan emitted rules (.cursor/rules/ai-kit-*.mdc) not in plugin
  4. Stale entries in project .claude/settings.json hooks

Options:
  path     Project path (default: pwd). Used for surfaces 3 and 4.
  --json   Machine-readable output.
  --fix    Print suggested rm/cleanup commands (does NOT execute them).

Exit codes:
  0  no duplicates found
  1  duplicates found
  2  usage error
USAGE
}

MODE_JSON=0
MODE_FIX=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --json) MODE_JSON=1 ;;
    --fix) MODE_FIX=1 ;;
    -*) echo "Unknown flag: $arg" >&2; usage; exit 2 ;;
    *)
      if [ -n "$TARGET" ]; then echo "Unexpected arg: $arg" >&2; usage; exit 2; fi
      TARGET="$arg"
      ;;
  esac
done
TARGET="${TARGET:-$PWD}"
if [ ! -d "$TARGET" ]; then
  echo "Not a directory: $TARGET" >&2
  exit 2
fi

PLUGIN_SKILLS_DIR="$AIKIT/workflow/skills"
PLUGIN_AGENTS_DIR="$AIKIT/workflow/agents"
PLUGIN_RULES_DIR="$AIKIT/standards/rules"
PERSONAL_SKILLS_DIR="$HOME/.claude/skills"
PERSONAL_AGENTS_DIR="$HOME/.claude/agents"
PROJECT_CURSOR_RULES="$TARGET/.cursor/rules"
PROJECT_SETTINGS="$TARGET/.claude/settings.json"

DUP_SKILLS=()
DUP_AGENTS=()
ORPHAN_RULES=()
HOOK_NOTES=()

# Surface 1: personal skills shadowing plugin skills
if [ -d "$PERSONAL_SKILLS_DIR" ] && [ -d "$PLUGIN_SKILLS_DIR" ]; then
  for skill_path in "$PLUGIN_SKILLS_DIR"/*/; do
    name="$(basename "$skill_path")"
    if [ -d "$PERSONAL_SKILLS_DIR/$name" ]; then
      DUP_SKILLS+=("$name")
    fi
  done
fi

# Surface 2: personal agents shadowing plugin agents
if [ -d "$PERSONAL_AGENTS_DIR" ] && [ -d "$PLUGIN_AGENTS_DIR" ]; then
  for agent_path in "$PLUGIN_AGENTS_DIR"/*/; do
    name="$(basename "$agent_path")"
    # personal agents are flat .md files; match <name>.md
    if [ -f "$PERSONAL_AGENTS_DIR/$name.md" ]; then
      DUP_AGENTS+=("$name")
    fi
  done
fi

# Surface 3: orphan ai-kit-* rules in project .cursor/rules/
if [ -d "$PROJECT_CURSOR_RULES" ] && [ -d "$PLUGIN_RULES_DIR" ]; then
  # Build list of plugin rule names (stem of *.mini.md / *.nano.md)
  PLUGIN_RULE_STEMS=()
  for rule_file in "$PLUGIN_RULES_DIR"/*.md; do
    [ -f "$rule_file" ] || continue
    stem="$(basename "$rule_file")"
    stem="${stem%.mini.md}"
    stem="${stem%.nano.md}"
    stem="${stem%.md}"
    PLUGIN_RULE_STEMS+=("$stem")
  done
  for emitted in "$PROJECT_CURSOR_RULES"/ai-kit-*.mdc; do
    [ -f "$emitted" ] || continue
    base="$(basename "$emitted" .mdc)"
    base="${base#ai-kit-}"
    found=0
    for stem in "${PLUGIN_RULE_STEMS[@]}"; do
      if [ "$stem" = "$base" ]; then found=1; break; fi
    done
    if [ "$found" -eq 0 ]; then
      ORPHAN_RULES+=("$emitted")
    fi
  done
fi

# Surface 4: project .claude/settings.json hook overlap (informational)
if [ -f "$PROJECT_SETTINGS" ]; then
  if grep -q "ai-kit" "$PROJECT_SETTINGS" 2>/dev/null; then
    HOOK_NOTES+=("$PROJECT_SETTINGS references 'ai-kit' — verify hook paths still resolve under current plugin layout")
  fi
fi

TOTAL=$(( ${#DUP_SKILLS[@]} + ${#DUP_AGENTS[@]} + ${#ORPHAN_RULES[@]} ))

if [ "$MODE_JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "target": "%s",\n' "$TARGET"
  printf '  "ai_kit_root": "%s",\n' "$AIKIT"
  printf '  "dup_skills": ['
  first=1
  for s in "${DUP_SKILLS[@]}"; do
    [ "$first" -eq 1 ] || printf ', '; first=0
    printf '"%s"' "$s"
  done
  printf '],\n'
  printf '  "dup_agents": ['
  first=1
  for s in "${DUP_AGENTS[@]}"; do
    [ "$first" -eq 1 ] || printf ', '; first=0
    printf '"%s"' "$s"
  done
  printf '],\n'
  printf '  "orphan_rules": ['
  first=1
  for s in "${ORPHAN_RULES[@]}"; do
    [ "$first" -eq 1 ] || printf ', '; first=0
    printf '"%s"' "$s"
  done
  printf '],\n'
  printf '  "hook_notes": ['
  first=1
  for s in "${HOOK_NOTES[@]}"; do
    [ "$first" -eq 1 ] || printf ', '; first=0
    printf '"%s"' "$(printf '%s' "$s" | sed 's/"/\\"/g')"
  done
  printf '],\n'
  printf '  "total": %d\n' "$TOTAL"
  printf '}\n'
  if [ "$TOTAL" -gt 0 ]; then exit 1; else exit 0; fi
fi

# Human-readable report
echo "ai-kit dedupe"
echo "  target          $TARGET"
echo "  ai-kit root     $AIKIT"
echo "  personal skills $PERSONAL_SKILLS_DIR"
echo "  personal agents $PERSONAL_AGENTS_DIR"
echo ""

echo "Surface 1 — Personal skills shadowing plugin skills"
if [ ${#DUP_SKILLS[@]} -eq 0 ]; then
  echo "  ok  no overlap"
else
  for s in "${DUP_SKILLS[@]}"; do
    echo "  DUP  $s  (personal: $PERSONAL_SKILLS_DIR/$s/)"
  done
fi
echo ""

echo "Surface 2 — Personal agents shadowing plugin agents"
if [ ${#DUP_AGENTS[@]} -eq 0 ]; then
  echo "  ok  no overlap"
else
  for s in "${DUP_AGENTS[@]}"; do
    echo "  DUP  $s  (personal: $PERSONAL_AGENTS_DIR/$s.md)"
  done
fi
echo ""

echo "Surface 3 — Orphan emitted rules in project"
if [ ${#ORPHAN_RULES[@]} -eq 0 ]; then
  echo "  ok  no orphans"
else
  for s in "${ORPHAN_RULES[@]}"; do
    echo "  ORPHAN  $s"
  done
fi
echo ""

echo "Surface 4 — Project settings hook notes"
if [ ${#HOOK_NOTES[@]} -eq 0 ]; then
  echo "  ok  no notes"
else
  for s in "${HOOK_NOTES[@]}"; do
    echo "  info  $s"
  done
fi
echo ""

if [ "$MODE_FIX" -eq 1 ] && [ "$TOTAL" -gt 0 ]; then
  echo "Suggested cleanup (review before running)"
  for s in "${DUP_SKILLS[@]}"; do
    echo "  rm -rf \"$PERSONAL_SKILLS_DIR/$s\""
  done
  for s in "${DUP_AGENTS[@]}"; do
    echo "  rm \"$PERSONAL_AGENTS_DIR/$s.md\""
  done
  for s in "${ORPHAN_RULES[@]}"; do
    echo "  rm \"$s\""
  done
  echo ""
fi

if [ "$TOTAL" -gt 0 ]; then
  echo "Found $TOTAL duplicate/orphan item(s). Re-run with --fix to see cleanup commands."
  exit 1
else
  echo "Clean — no duplicates or orphans found."
  exit 0
fi
