#!/usr/bin/env bash
# Diagnose ai-kit setup health: env, global install, project (if given).
# Exit 0 = all green; 1 = warnings; 2 = errors (fix before continuing).
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
KIT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"

usage() {
  echo "Usage: $0 [path] [--project-only|--check-global]"
  echo ""
  echo "Diagnoses ai-kit env + (optionally) global install + project."
  echo ""
  echo "Mode detection:"
  echo "  --project-only    skip global-install checks (project-scoped install)"
  echo "  --check-global    force global-install checks even if marker says project-only"
  echo "  (none)            read setup_mode from <path>/.ai-kit-setup; default to checking"
}

MODE="auto"
TARGET=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --project-only) MODE="project-only" ;;
    --check-global) MODE="check-global" ;;
    -*) echo "Unknown flag: $arg" >&2; usage; exit 2 ;;
    *)
      if [ -n "$TARGET" ]; then echo "Unexpected arg: $arg" >&2; usage; exit 2; fi
      TARGET="$arg"
      ;;
  esac
done

WARN=0
ERR=0
ok()   { echo "  ok    $*"; }
warn() { echo "  warn  $*"; WARN=$((WARN + 1)); }
err()  { echo "  ERR   $*"; ERR=$((ERR + 1)); }

echo "ai-kit doctor"
echo "  root  $AIKIT (v$KIT_VERSION)"
echo ""

echo "Env"
if [ -n "${AI_KIT_ROOT:-}" ]; then
  if [ "$AI_KIT_ROOT" = "$AIKIT" ]; then
    ok "AI_KIT_ROOT matches resolved root"
  else
    warn "AI_KIT_ROOT=$AI_KIT_ROOT but resolved root is $AIKIT"
  fi
else
  if [ -f "$HOME/.config/ai-kit/root" ]; then
    ok "AI_KIT_ROOT unset; fallback ~/.config/ai-kit/root works"
  else
    warn "AI_KIT_ROOT unset and no ~/.config/ai-kit/root — run install-global.sh"
  fi
fi

if command -v python3 >/dev/null 2>&1; then
  ok "python3 available ($(python3 --version 2>&1))"
else
  err "python3 not on PATH — marker/upgrade/status scripts will fail"
fi
echo ""

# Decide whether to check globals. Project-only setups don't depend on them.
EFFECTIVE_MODE="$MODE"
if [ "$EFFECTIVE_MODE" = "auto" ] && [ -n "$TARGET" ] && [ -f "$TARGET/.ai-kit-setup" ]; then
  setup_mode="$(python3 -c "import json,sys; print(json.load(open('$TARGET/.ai-kit-setup')).get('branches',{}).get('setup_mode',''))" 2>/dev/null || echo "")"
  if [ "$setup_mode" = "project-only" ]; then
    EFFECTIVE_MODE="project-only"
  fi
fi

if [ "$EFFECTIVE_MODE" = "project-only" ]; then
  echo "Global install"
  echo "  info  skipped — setup-mode is project-only (globals not required)"
  echo ""
else
  echo "Global install"
  GLOBAL_CLAUDE="$HOME/.claude/skills"
  GLOBAL_AGENTS="$HOME/.agents/skills"
  GLOBAL_CURSOR="$HOME/.cursor/skills"
  for d in "$GLOBAL_CLAUDE" "$GLOBAL_AGENTS" "$GLOBAL_CURSOR"; do
    if [ -d "$d" ]; then
      count="$(find "$d" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' ')"
      aikit_links="$(find "$d" -mindepth 1 -maxdepth 1 -type l 2>/dev/null -exec readlink {} \; 2>/dev/null | grep -c "$AIKIT" || true)"
      if [ "$aikit_links" -gt 0 ]; then
        ok "$d — $count entries ($aikit_links linked to this ai-kit)"
      else
        warn "$d — $count entries but none link to $AIKIT (run install-global.sh, or use --project-only)"
      fi
    else
      warn "$d absent — run install-global.sh, or use --project-only if you don't want globals"
    fi
  done
  echo ""
fi

if [ -n "$TARGET" ]; then
  if [ ! -d "$TARGET" ]; then
    err "Project path not a directory: $TARGET"
  else
    TARGET="$(cd "$TARGET" && pwd)"
    echo "Project: $TARGET"
    for d in .claude/skills .agents/skills .cursor/skills; do
      p="$TARGET/$d"
      if [ ! -d "$p" ]; then
        warn "$d absent (run bootstrap-project.sh)"
        continue
      fi
      entries="$(find "$p" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' ')"
      broken="$(find "$p" -mindepth 1 -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')"
      if [ "$broken" -gt 0 ]; then
        err "$d — $broken broken symlinks (ai-kit moved? run bootstrap-project.sh)"
      elif [ "$entries" -eq 0 ]; then
        warn "$d empty"
      else
        ok "$d — $entries entries resolve"
      fi
    done

    if [ -f "$TARGET/.ai-kit-setup" ]; then
      mver="$(python3 -c "import json; print(json.load(open('$TARGET/.ai-kit-setup')).get('ai_kit_version','?'))")"
      if [ "$mver" = "$KIT_VERSION" ]; then
        ok ".ai-kit-setup version matches ($mver)"
      else
        warn ".ai-kit-setup version $mver != ai-kit $KIT_VERSION — run ai-kit-upgrade.sh"
      fi
    else
      warn ".ai-kit-setup absent — /setup not yet run"
    fi
  fi
  echo ""
fi

if [ "$ERR" -gt 0 ]; then
  echo "Summary: $ERR error(s), $WARN warning(s) — fix errors before continuing"
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo "Summary: $WARN warning(s) — usable, but follow the suggested fixes"
  exit 1
else
  echo "Summary: all green"
  exit 0
fi
