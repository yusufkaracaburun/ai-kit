#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/detect-lib.sh
source "$AIKIT/bin/lib/detect-lib.sh"
# shellcheck source=lib/emitter-lib.sh
source "$AIKIT/bin/lib/emitter-lib.sh"
# shellcheck source=lib/emitters/cursor.sh
source "$AIKIT/bin/lib/emitters/cursor.sh"
# shellcheck source=lib/emitters/claude-code.sh
source "$AIKIT/bin/lib/emitters/claude-code.sh"
# shellcheck source=lib/emitters/generic.sh
source "$AIKIT/bin/lib/emitters/generic.sh"

VERSION_FILE="$AIKIT/VERSION"
[ -f "$VERSION_FILE" ] || { echo "ai-kit VERSION file missing" >&2; exit 2; }
AIKIT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

usage() {
  cat <<EOF
Usage: $0 <project> [options]

Emit canonical rules from \$AI_KIT_ROOT/standards/rules/*.mini.md to the
target project in formats appropriate for each detected AI agent.

Options:
  --rules NAME[,NAME...]  Rules to emit. Default: every universal rule.
  --agents A[,A...]       Override detection (cursor, claude-code, aider, …).
  --mode MODE             always-on | on-demand. Default: rule-frontmatter.
  --dry-run               Print what would be emitted, don't write.
  --list                  List available rules + their universal flag, exit.
  -h, --help              Show this help.

Detected agents are listed by \`detect_agents\`. \`generic\` is always added
so docs/agents/active-rules.md tracks the canonical list regardless of agent.
EOF
  exit 1
}

PROJECT=""
RULES_CSV=""
AGENTS_CSV=""
MODE_OVERRIDE=""
DRY_RUN=false
LIST_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --rules) RULES_CSV="$2"; shift 2 ;;
    --agents) AGENTS_CSV="$2"; shift 2 ;;
    --mode) MODE_OVERRIDE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --list) LIST_ONLY=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *)
      if [ -n "$PROJECT" ]; then echo "Unexpected: $1" >&2; usage; fi
      PROJECT="$1"; shift ;;
  esac
done

RULES_DIR="$AIKIT/standards/rules"

list_rules() {
  for f in "$RULES_DIR"/*.mini.md "$RULES_DIR"/*.nano.md; do
    [ -f "$f" ] || continue
    local name universal weight
    name="$(basename "$f")"
    name="${name%.mini.md}"
    name="${name%.nano.md}"
    universal="$(_emitter_extract_meta "$f" universal)"
    weight="$(_emitter_extract_meta "$f" weight)"
    printf "%-22s universal=%-5s weight=%s\n" "$name" "${universal:-false}" "${weight:-medium}"
  done
}

if [ "$LIST_ONLY" = true ]; then
  list_rules
  exit 0
fi

[ -z "$PROJECT" ] && usage
[ -d "$PROJECT" ] || { echo "Project not found: $PROJECT" >&2; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"

# Resolve agents.
if [ -n "$AGENTS_CSV" ]; then
  IFS=',' read -r -a DETECTED_AGENTS <<< "$AGENTS_CSV"
else
  detect_agents "$PROJECT"
fi

# Always include generic so AGENTS.md index reflects active set.
case " ${DETECTED_AGENTS[*]+${DETECTED_AGENTS[*]}} " in
  *" generic "*) ;;
  *) DETECTED_AGENTS+=("generic") ;;
esac

# Resolve rule list.
declare -a RULES=()
if [ -n "$RULES_CSV" ]; then
  IFS=',' read -r -a RULES <<< "$RULES_CSV"
else
  for f in "$RULES_DIR"/*.mini.md "$RULES_DIR"/*.nano.md; do
    [ -f "$f" ] || continue
    universal="$(_emitter_extract_meta "$f" universal)"
    if [ "$universal" = "true" ]; then
      name="$(basename "$f")"
      name="${name%.mini.md}"
      name="${name%.nano.md}"
      RULES+=("$name")
    fi
  done
fi

if [ "${#RULES[@]}" -eq 0 ]; then
  echo "No rules selected (no universal=true rules found and no --rules given)" >&2
  exit 0
fi

resolve_rule_path() {
  local name="$1"
  for ext in mini.md nano.md; do
    if [ -f "$RULES_DIR/${name}.${ext}" ]; then
      echo "$RULES_DIR/${name}.${ext}"
      return 0
    fi
  done
  return 1
}

dispatch() {
  local agent="$1" target="$2" rule_path="$3" rule_name="$4" mode="$5" version="$6"
  case "$agent" in
    cursor)       emit_cursor       "$target" "$rule_path" "$rule_name" "$mode" "$version" ;;
    claude-code)  emit_claude_code  "$target" "$rule_path" "$rule_name" "$mode" "$version" ;;
    generic|agents-md) emit_generic "$target" "$rule_path" "$rule_name" "$mode" "$version" ;;
    aider|cline|continue|cody)
      echo "skip:${agent}  (emitter not yet implemented — see docs/roadmap.md item #1)" ;;
    *) echo "skip:${agent}  (unknown agent)" ;;
  esac
}

echo "ai-kit emit-rules @ ${AIKIT_VERSION}"
echo "  project: $PROJECT"
echo "  agents:  ${DETECTED_AGENTS[*]}"
echo "  rules:   ${RULES[*]}"
[ "$DRY_RUN" = true ] && echo "  mode:    dry-run (no files written)"
echo ""

for rule in "${RULES[@]}"; do
  rule_path="$(resolve_rule_path "$rule" || true)"
  if [ -z "$rule_path" ]; then
    echo "warn: rule '${rule}' not found in $RULES_DIR" >&2
    continue
  fi

  if [ -n "$MODE_OVERRIDE" ]; then
    mode="$MODE_OVERRIDE"
  else
    mode="$(_emitter_extract_meta "$rule_path" default_mode)"
    [ -z "$mode" ] && mode="on-demand"
  fi

  for agent in "${DETECTED_AGENTS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
      echo "would-emit:${agent}  ${rule}  (mode=${mode})"
    else
      dispatch "$agent" "$PROJECT" "$rule_path" "$rule" "$mode" "$AIKIT_VERSION"
    fi
  done
done
