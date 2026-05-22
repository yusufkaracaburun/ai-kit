#!/usr/bin/env bash
# Validate ai-kit setup state for a project.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
EXPECTED_VERSION="$(cat "$AIKIT/VERSION" | tr -d '[:space:]')"

usage() {
  echo "Usage: $0 /path/to/project [--strict] [--minimal]"
  echo ""
  echo "  --minimal  Tier-A checks only (or read branches.setup_tier from marker)"
  exit 1
}

if [ $# -lt 1 ]; then usage; fi

TARGET="$(cd "$1" && pwd)"
STRICT=false
FORCE_MINIMAL=false
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=true; shift ;;
    --minimal) FORCE_MINIMAL=true; shift ;;
    -h | --help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

PASS=0
FAIL=0
FAIL_MSGS=()

check() {
  local name="$1"
  local ok="$2"
  if [ "$ok" = true ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("$name")
  fi
}

bool() {
  if "$@"; then echo true; else echo false; fi
}

SETUP_FILE="$TARGET/.ai-kit-setup"
SETUP_MODE=""
SETUP_TIER=""
ARCH_BRANCH="skipped"
DOCKER_BRANCH=""
SETUP_JSON=""

if [ -f "$SETUP_FILE" ]; then
  SETUP_JSON="$(cat "$SETUP_FILE")"
  SETUP_MODE="$(python3 -c "
import json, sys
d = json.load(sys.stdin)
b = d.get('branches', {})
print(b.get('setup_mode') or b.get('agent_stack') or '')
" <<<"$SETUP_JSON" 2>/dev/null || echo "")"
  SETUP_TIER="$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('branches', {}).get('setup_tier', ''))
" <<<"$SETUP_JSON" 2>/dev/null || echo "")"
  ARCH_BRANCH="$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('branches', {}).get('architecture', 'skipped'))
" <<<"$SETUP_JSON" 2>/dev/null || echo skipped)"
  DOCKER_BRANCH="$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('branches', {}).get('docker', 'skipped'))
" <<<"$SETUP_JSON" 2>/dev/null || echo skipped)"
fi

# Legacy mode aliases
case "$SETUP_MODE" in
  global-only) SETUP_MODE="solo-global" ;;
  merge-skills | link-all) SETUP_MODE="solo-both" ;;
  parallel) SETUP_MODE="brownfield" ;;
esac

MINIMAL_TIER=false
if [ "$FORCE_MINIMAL" = true ] || [ "$SETUP_TIER" = "minimal" ]; then
  MINIMAL_TIER=true
fi

# Bootstrap
if [ -f "$TARGET/AGENTS.md" ] || [ -f "$TARGET/CLAUDE.md" ]; then
  check "AGENTS.md or CLAUDE.md" true
else
  check "AGENTS.md or CLAUDE.md" false
fi

SKILLS_REQUIRED=true
if [ "$SETUP_MODE" = "solo-global" ]; then
  SKILLS_REQUIRED=false
fi

if [ "$SKILLS_REQUIRED" = true ]; then
  if [ -d "$TARGET/.claude/skills" ] || [ -L "$TARGET/.claude/skills" ]; then
    check ".claude/skills present" true
  else
    check ".claude/skills present" false
  fi

  if [ -d "$TARGET/.agents/skills" ] || [ -L "$TARGET/.agents/skills" ]; then
    check ".agents/skills present" true
  else
    check ".agents/skills present" false
  fi

  if [ -d "$TARGET/.cursor/skills" ] || [ -L "$TARGET/.cursor/skills" ]; then
    check ".cursor/skills present" true
  else
    check ".cursor/skills present" false
  fi
else
  check ".claude/skills skipped (solo-global)" true
  check ".agents/skills skipped (solo-global)" true
  check ".cursor/skills skipped (solo-global)" true
fi

check ".ai-kit-setup exists" "$(bool [ -f "$SETUP_FILE" ])"

if [ -f "$SETUP_FILE" ]; then
  check ".ai-kit-setup valid JSON" \
    "$(python3 -c "import json,sys; json.load(sys.stdin)" <<<"$SETUP_JSON" 2>/dev/null && echo true || echo false)"

  VERSION_OK="$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print('true' if d.get('ai_kit_version') == '$EXPECTED_VERSION' else 'false')
" <<<"$SETUP_JSON" 2>/dev/null || echo false)"
  if [ "$VERSION_OK" = true ]; then
    check ".ai-kit-setup version matches ai-kit" true
  else
    check ".ai-kit-setup version matches ai-kit" false
  fi
fi

check "dev-environment.md" "$(bool [ -f "$TARGET/docs/agents/dev-environment.md" ])"

if [ "$SETUP_MODE" = "brownfield" ]; then
  check "agent-stack.md (brownfield)" \
    "$(bool [ -f "$TARGET/docs/agents/agent-stack.md" ])"
fi

if [ "$MINIMAL_TIER" = false ]; then
  if [ "$DOCKER_BRANCH" != "skipped" ] && [ -n "$DOCKER_BRANCH" ]; then
    check "docker.md (docker branch active)" "$(bool [ -f "$TARGET/docs/agents/docker.md" ])"
  fi

  check "issue-tracker.md" "$(bool [ -f "$TARGET/docs/agents/issue-tracker.md" ])"
  check "triage-labels.md" "$(bool [ -f "$TARGET/docs/agents/triage-labels.md" ])"
  check "domain.md" "$(bool [ -f "$TARGET/docs/agents/domain.md" ])"
  check "workflow.md" "$(bool [ -f "$TARGET/docs/agents/workflow.md" ])"

  if [ "$ARCH_BRANCH" != "skipped" ]; then
    check "architecture.md (architecture branch active)" \
      "$(bool [ -f "$TARGET/docs/agents/architecture.md" ])"
  fi

  if { [ -f "$TARGET/AGENTS.md" ] && grep -qE 'Agent skills|Agile lifecycle' "$TARGET/AGENTS.md" 2>/dev/null; } \
    || { [ -f "$TARGET/CLAUDE.md" ] && grep -qE 'Agent skills|Agile lifecycle' "$TARGET/CLAUDE.md" 2>/dev/null; }; then
    check "agent skills / lifecycle section" true
  else
    check "agent skills / lifecycle section" false
  fi
fi

if [ "$STRICT" = true ]; then
  DEV_ENV="$TARGET/docs/agents/dev-environment.md"
  if [ -f "$DEV_ENV" ]; then
    check "dev-environment: no setup placeholder" \
      "$( ! grep -q 'Filled by /aikit-setup' "$DEV_ENV" 2>/dev/null && echo true || echo false)"
    check "dev-environment: docs table has URL" \
      "$(grep -qE 'https?://' "$DEV_ENV" 2>/dev/null && echo true || echo false)"
  fi

  ARCH_FILE="$TARGET/docs/agents/architecture.md"
  if [ "$MINIMAL_TIER" = false ] && [ -f "$ARCH_FILE" ] && [ "$ARCH_BRANCH" != "skipped" ]; then
    check "architecture: FE section not placeholder" \
      "$( ! grep -qE '\*\*Approach:\*\* \[e\.g\.' "$ARCH_FILE" 2>/dev/null && echo true || echo false)"
    check "architecture: BE section not placeholder" \
      "$( ! grep -qE '\*\*Layout:\*\* \[key paths' "$ARCH_FILE" 2>/dev/null && echo true || echo false)"
  fi
fi

TOTAL=$((PASS + FAIL))
echo "SETUP VERIFY: ${PASS}/${TOTAL} passed"

if [ "$FAIL" -gt 0 ]; then
  for msg in "${FAIL_MSGS[@]}"; do
    echo "FAIL: $msg"
  done
  exit 1
fi

exit 0
