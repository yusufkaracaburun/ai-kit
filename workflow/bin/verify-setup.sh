#!/usr/bin/env bash
# Validate ai-kit setup state for a project.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
# shellcheck source=lib/setup-marker.sh
source "$SCRIPT_BIN/lib/setup-marker.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
EXPECTED_VERSION="$(resolve_ai_kit_version "$AIKIT")"

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
SECRETS_SCAN_BRANCH=""
DOMAIN_DOCS_BRANCH=""
PROJECT_SKILLS_MERGED_RAW=""
SETUP_VALID=false
MARKER_VERSION=""

# A corrupt marker prints its parse error here and fails the checks below.
if [ -f "$SETUP_FILE" ] && MARKER_VERSION="$(marker_get "$SETUP_FILE" ai_kit_version)"; then
  SETUP_VALID=true
  SETUP_MODE="$(marker_get "$SETUP_FILE" branches.setup_mode)"
  [ -n "$SETUP_MODE" ] || SETUP_MODE="$(marker_get "$SETUP_FILE" branches.agent_stack)"
  SETUP_TIER="$(marker_get "$SETUP_FILE" branches.setup_tier)"
  ARCH_BRANCH="$(marker_get "$SETUP_FILE" branches.architecture skipped)"
  DOCKER_BRANCH="$(marker_get "$SETUP_FILE" branches.docker skipped)"
  SECRETS_SCAN_BRANCH="$(marker_get "$SETUP_FILE" branches.secrets_scan)"
  DOMAIN_DOCS_BRANCH="$(marker_get "$SETUP_FILE" branches.domain_docs)"
  # skip_skill_merge=true is the v1.79 retrofit of project_skills_merged=false
  # (ADR-0012); a marker written between the two carries only the old field.
  PROJECT_SKILLS_MERGED_RAW="$(marker_get "$SETUP_FILE" branches.project_skills_merged)"
  if [ -z "$PROJECT_SKILLS_MERGED_RAW" ] && [ "$(marker_get "$SETUP_FILE" branches.skip_skill_merge)" = true ]; then
    PROJECT_SKILLS_MERGED_RAW=false
  fi
fi

# Legacy mode aliases
case "$SETUP_MODE" in
  global-only) SETUP_MODE="solo-global" ;;
  merge-skills | link-all) SETUP_MODE="solo-both" ;;
  parallel) SETUP_MODE="brownfield" ;;
esac

# ADR-0012 phase (d): prefer the explicit dual-written field once a marker
# has it; fall back to deriving from setup_mode for markers written before
# phase (c) — solo-global is the only legacy value that meant "skip the
# project skills dirs", every other value (including no marker at all)
# meant "merge them." Zero behavior change for every marker on disk today.
if [ -n "$PROJECT_SKILLS_MERGED_RAW" ]; then
  PROJECT_SKILLS_MERGED="$PROJECT_SKILLS_MERGED_RAW"
elif [ "$SETUP_MODE" = "solo-global" ]; then
  PROJECT_SKILLS_MERGED=false
else
  PROJECT_SKILLS_MERGED=true
fi

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

SKILLS_REQUIRED="$PROJECT_SKILLS_MERGED"

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
  check ".claude/skills skipped (project_skills_merged=false)" true
  check ".agents/skills skipped (project_skills_merged=false)" true
  check ".cursor/skills skipped (project_skills_merged=false)" true
fi

check ".ai-kit-setup exists" "$(bool [ -f "$SETUP_FILE" ])"

if [ -f "$SETUP_FILE" ]; then
  check ".ai-kit-setup valid JSON" "$SETUP_VALID"

  if [ "$SETUP_VALID" = true ] && [ "$MARKER_VERSION" = "$EXPECTED_VERSION" ]; then
    check ".ai-kit-setup version matches ai-kit" true
  else
    check ".ai-kit-setup version matches ai-kit" false
  fi

  # #124 — mandatory Tier-A branch, every setup mode. Value doesn't matter
  # here (clean/findings/skipped-* all mean the branch ran); an empty string
  # means a pre-#124 project or a wiring bug, either way worth flagging.
  check "secrets_scan recorded (pre-#124 project — run /ai:setup once to backfill)" \
    "$(bool [ -n "$SECRETS_SCAN_BRANCH" ])"
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
  # domain.md is written only by the domain_docs branch (bootstrap copies
  # workflow.md, never domain.md), so a skipped branch owes no file; an older
  # marker without the key keeps the unconditional check.
  if [ "$DOMAIN_DOCS_BRANCH" != "skipped" ]; then
    check "domain.md" "$(bool [ -f "$TARGET/docs/agents/domain.md" ])"
  fi
  check "workflow.md" "$(bool [ -f "$TARGET/docs/agents/workflow.md" ])"

  if [ "$ARCH_BRANCH" != "skipped" ]; then
    check "architecture.md (architecture branch active)" \
      "$(bool [ -f "$TARGET/docs/agents/architecture.md" ])"
  fi

  # Identifiers, not an English heading: a skills path survives translation,
  # "Agile lifecycle" does not. A Dutch CLAUDE.md that documented the phases
  # and the skills in full failed here on one word, and the only way to green
  # was to bend the docs to the grep. The two original headings stay in the
  # pattern for docs that describe the skills without naming a path.
  #
  # A bare `/ai:` mention is deliberately NOT a match. It would pass any doc
  # that names a command in passing ("soms draai ik /ai:doctor"), turning a
  # check about documenting the setup into a check for one string. The skills
  # path is the language-independent identifier; it is enough on its own.
  SKILLS_SECTION_RE='Agent skills|Agile lifecycle|\.(claude|agents|cursor)/skills'
  if { [ -f "$TARGET/AGENTS.md" ] && grep -qE "$SKILLS_SECTION_RE" "$TARGET/AGENTS.md" 2>/dev/null; } \
    || { [ -f "$TARGET/CLAUDE.md" ] && grep -qE "$SKILLS_SECTION_RE" "$TARGET/CLAUDE.md" 2>/dev/null; }; then
    check "agent skills / lifecycle section" true
  else
    check "agent skills / lifecycle section" false
  fi
fi

if [ "$STRICT" = true ]; then
  # #114 (naschool): a symlink pinned straight into a version-numbered
  # plugin cache dir (rather than through the plugin-current indirection)
  # resolves fine today and bricks silently on the next /plugin update GC.
  # Presence-only checks above never catch this — flag it explicitly.
  count_stale_plugin_links() {
    local p="$1" n=0 entry target
    if [ -L "$p" ]; then
      target="$(readlink "$p")"
      [[ "$target" == */plugins/cache/* && "$target" != *plugin-current* ]] && n=$((n + 1))
    elif [ -d "$p" ]; then
      for entry in "$p"/*; do
        [ -L "$entry" ] || continue
        target="$(readlink "$entry")"
        [[ "$target" == */plugins/cache/* && "$target" != *plugin-current* ]] && n=$((n + 1))
      done
    fi
    echo "$n"
  }
  if [ "$SKILLS_REQUIRED" = true ]; then
    STALE_LINKS=0
    for d in .claude/skills .agents/skills .cursor/skills .claude/agents .claude/commands .cursor/commands; do
      p="$TARGET/$d"
      [ -e "$p" ] || [ -L "$p" ] || continue
      STALE_LINKS=$((STALE_LINKS + $(count_stale_plugin_links "$p")))
    done
    check "no version-pinned plugin links ($STALE_LINKS found — will break on next GC, run /ai:upgrade)" \
      "$(bool [ "$STALE_LINKS" -eq 0 ])"
  fi

  DEV_ENV="$TARGET/docs/agents/dev-environment.md"
  if [ -f "$DEV_ENV" ]; then
    check "dev-environment: no setup placeholder" \
      "$( ! grep -q 'Filled by /ai:setup' "$DEV_ENV" 2>/dev/null && echo true || echo false)"
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
