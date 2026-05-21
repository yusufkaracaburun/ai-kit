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
info() { echo "  info  $*"; }
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
    # Script-location fallback resolved AIKIT successfully — globals are
    # optional, so this is advisory, not a warning. Counting it as a warn
    # caused project-only setups to exit 1 even when fully functional.
    info "AI_KIT_ROOT unset; using script-location fallback ($AIKIT). Run install-global.sh for global skill links if desired."
  fi
fi

if command -v python3 >/dev/null 2>&1; then
  ok "python3 available ($(python3 --version 2>&1))"
else
  err "python3 not on PATH — marker/upgrade/status scripts will fail"
fi
echo ""

# Decide whether to check globals.
#   1. CLI flags always win.
#   2. If a project marker has setup_mode=project-only, skip.
#   3. If a project marker has any OTHER setup_mode (solo-both, solo-global,
#      brownfield) — project explicitly opted into globals, so CHECK them even
#      if the machine has opted out. (Project intent beats machine preference.)
#   4. Otherwise (no project context, or marker has no setup_mode), respect
#      the machine-wide opt-out marker if present.
#   5. Otherwise, check globals as normal.
EFFECTIVE_MODE="$MODE"
SKIP_REASON=""
HAS_PROJECT_MODE=false
if [ "$EFFECTIVE_MODE" = "auto" ] && [ -n "$TARGET" ] && [ -f "$TARGET/.ai-kit-setup" ]; then
  setup_mode="$(python3 -c "import json,sys; print(json.load(open('$TARGET/.ai-kit-setup')).get('branches',{}).get('setup_mode',''))" 2>/dev/null || echo "")"
  if [ -n "$setup_mode" ]; then
    HAS_PROJECT_MODE=true
    if [ "$setup_mode" = "project-only" ]; then
      EFFECTIVE_MODE="project-only"
      SKIP_REASON="setup-mode is project-only (globals not required)"
    fi
  fi
fi
if [ "$EFFECTIVE_MODE" = "auto" ] && [ "$HAS_PROJECT_MODE" = false ] && [ -f "${HOME}/.config/ai-kit/no-globals" ]; then
  EFFECTIVE_MODE="project-only"
  SKIP_REASON="machine opt-out via ${HOME}/.config/ai-kit/no-globals"
fi

if [ "$EFFECTIVE_MODE" = "project-only" ]; then
  echo "Global install"
  echo "  info  skipped — ${SKIP_REASON:-setup-mode is project-only (globals not required)}"
  echo ""
else
  echo "Global install"
  GLOBAL_CLAUDE="$HOME/.claude/skills"
  GLOBAL_AGENTS="$HOME/.agents/skills"
  GLOBAL_CURSOR="$HOME/.cursor/skills"
  for d in "$GLOBAL_CLAUDE" "$GLOBAL_AGENTS" "$GLOBAL_CURSOR"; do
    if [ -d "$d" ]; then
      count="$(find "$d" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' ')"
      aikit_links="$(find "$d" -mindepth 1 -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -c "$AIKIT" || true)"
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

echo "Plugin install"
PLUGIN_MANIFEST="$AIKIT/workflow/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_MANIFEST" ]; then
  PLUGIN_VER="$(python3 -c "import json; print(json.load(open('$PLUGIN_MANIFEST')).get('version','?'))" 2>/dev/null || echo "?")"
  if [ "$PLUGIN_VER" = "$KIT_VERSION" ]; then
    ok "plugin manifest present and matches VERSION ($PLUGIN_VER)"
  else
    warn "plugin manifest version $PLUGIN_VER != VERSION $KIT_VERSION (run sync-plugin-version.sh)"
  fi
else
  info "no plugin manifest at $PLUGIN_MANIFEST (plugin distribution skipped)"
fi

# Detect a marketplace-installed ai-kit plugin coexisting with the
# symlink-install. Both work, but skill resolution gets confusing if the
# plugin and the symlinks point at different ai-kit clones.
INSTALLED_PLUGIN="$HOME/.claude/plugins/marketplaces/ai-kit"
if [ -d "$INSTALLED_PLUGIN" ] && [ "$EFFECTIVE_MODE" != "project-only" ]; then
  if [ -d "$HOME/.claude/skills" ]; then
    GLOBAL_AI_LINKS="$(find "$HOME/.claude/skills" -mindepth 1 -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -c "$AIKIT" || true)"
    if [ "$GLOBAL_AI_LINKS" -gt 0 ]; then
      warn "both plugin ($INSTALLED_PLUGIN) and symlink-install ($HOME/.claude/skills) active — pick one channel for updates (ai-kit-no-globals.sh on suppresses globals)"
    fi
  fi
fi
echo ""

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
