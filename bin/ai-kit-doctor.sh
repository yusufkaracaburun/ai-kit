#!/usr/bin/env bash
# Diagnose ai-kit setup health: env, global install, project (if given).
# Exit 0 = all green; 1 = warnings; 2 = errors (fix before continuing).
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
KIT_VERSION="$(resolve_ai_kit_version "$AIKIT")"

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

echo "Legacy gsd"
# Detect a co-installed "get-shit-done" footprint — ai-kit's predecessor.
# Its SessionStart hooks inject `gsd-*` skills into Claude Code's available-
# skills list even after ai-kit is installed, so they keep competing with
# `/ai:*` until the user runs `bin/ai-kit-migrate-gsd.sh --apply`.
#
# In project-only mode the user has opted out of machine-wide concerns, so
# downgrade the message from warn (exit 1) to info — don't break their CI.
GSD_HITS=0
for p in \
  "$HOME/.claude/get-shit-done" \
  "$HOME/.claude/gsd-file-manifest.json" \
  "$HOME/.claude/gsd-install-state.json" \
; do
  [ -e "$p" ] && GSD_HITS=$((GSD_HITS + 1))
done
if [ -d "$HOME/.claude/agents" ]; then
  GSD_HITS=$((GSD_HITS + $(find "$HOME/.claude/agents" -maxdepth 1 -iname "gsd-*" 2>/dev/null | wc -l | tr -d ' ')))
fi
if [ -d "$HOME/.claude/hooks" ]; then
  GSD_HITS=$((GSD_HITS + $(find "$HOME/.claude/hooks" -maxdepth 1 -iname "gsd-*" 2>/dev/null | wc -l | tr -d ' ')))
fi
if [ -f "$HOME/.claude/settings.json" ] && grep -q "gsd-" "$HOME/.claude/settings.json"; then
  GSD_HITS=$((GSD_HITS + 1))
fi
if [ "$GSD_HITS" -eq 0 ]; then
  ok "no legacy gsd footprint detected"
elif [ "$EFFECTIVE_MODE" = "project-only" ]; then
  info "$GSD_HITS gsd artifact(s) under ~/.claude — run bin/ai-kit-migrate-gsd.sh to remove (informational; project-only mode does not gate on this)"
else
  warn "$GSD_HITS gsd artifact(s) co-installed under ~/.claude — run bin/ai-kit-migrate-gsd.sh to inspect, then --apply to remove"
fi
echo ""

echo "Plugin install"
PLUGIN_MANIFEST="$(resolve_primitives_root "$AIKIT")/.claude-plugin/plugin.json"
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

echo "Audit-architecture extensions"
# Orphan-extension check: if an audit-architecture-<stack>/ folder is on
# disk without the core audit-architecture/ skill present, the extension
# loader will never see it (or worse — load it against a missing core).
# Warn so the install can be repaired before the next audit run.
# Use resolve_primitives_root so plugin-mode installs (skills at AIKIT/skills)
# are covered the same as dev-clone (skills at AIKIT/workflow/skills).
_audit_ext_root="$(resolve_primitives_root "$AIKIT")/skills"
if [ -d "$_audit_ext_root" ]; then
  _core_present=true
  [ -f "$_audit_ext_root/audit-architecture/SKILL.md" ] || _core_present=false
  _ext_count=0
  while IFS= read -r ext_skill; do
    [ -z "$ext_skill" ] && continue
    _ext_count=$((_ext_count + 1))
    _ext_name="$(basename "$(dirname "$ext_skill")")"
    if [ "$_core_present" = false ]; then
      warn "orphan extension: $_ext_name present but core audit-architecture/ skill missing"
    fi
  done < <(find "$_audit_ext_root" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -path '*/audit-architecture-*/SKILL.md' 2>/dev/null)
  if [ "$_ext_count" -eq 0 ]; then
    info "no audit-architecture-* extensions bundled"
  elif [ "$_core_present" = true ]; then
    ok "audit-architecture core + $_ext_count extension(s) present"
  fi
else
  info "workflow/skills/ absent — audit-extension check skipped"
fi
echo ""

echo "Workflow text drift"
# Lint workflow/skills/**/*.md + workflow/commands/**/*.md for team-size
# "solo" / "single dev" / "single developer" tokens. Excludes lines that
# also carry the install-layout vocabulary `setup_mode=solo-*` (parent grill
# Branch 1 of ai-kit #52). Regression guardrail against future drift after
# the parent sweep. Always warn (yellow), never error.
_workflow_lint_root="$AIKIT"
if [ ! -d "$_workflow_lint_root/workflow/skills" ] && [ ! -d "$_workflow_lint_root/workflow/commands" ]; then
  info "workflow/ directories absent at $_workflow_lint_root — lint skipped"
else
  # Exclusions:
  #   - setup_mode / solo-both / solo-global / [solo- → install-layout vocab
  #     (parent grill Branch 1 — different axis, must remain documented)
  #   - solo-human                                      → rule-discussion idiom
  #   - single-dev shortcut                             → anti-pattern naming
  #   - / solo /                                        → project-shape bullet idiom
  #   - solo-lint:allow                                 → explicit per-line opt-out
  _hits="$(grep -rniE '\b(solo|single[ -]dev|single[ -]developer)\b' \
    "$_workflow_lint_root/workflow/skills" \
    "$_workflow_lint_root/workflow/commands" \
    2>/dev/null \
    | grep -viE 'setup_mode|solo-both|solo-global|\[solo-|solo-human|single-dev shortcut|/ solo /|solo-lint:allow' \
    || true)"
  if [ -z "$_hits" ]; then
    ok "no team-size solo/single-dev token in workflow/skills + workflow/commands"
  else
    _count="$(printf '%s\n' "$_hits" | wc -l | tr -d ' ')"
    warn "team-size solo/single-dev string in workflow/ ($_count hit$([ "$_count" = 1 ] || echo s) — see ai-kit issue #52 for the 2-dev default rationale)"
    # Surface up to 3 hits so the user can see where to look without grep-ing.
    printf '%s\n' "$_hits" | head -3 | while IFS= read -r line; do
      info "    $line"
    done
    if [ "$_count" -gt 3 ]; then
      info "    … $((_count - 3)) more — re-run with: grep -rniE '\\\\b(solo|single[ -]dev|single[ -]developer)\\\\b' workflow/skills workflow/commands | grep -viE 'setup_mode|solo-both|solo-global|\\\\[solo-'"
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
      warn ".ai-kit-setup absent — /ai:setup not yet run"
    fi

    # ------------------------------------------------------------------
    # Single-dev drift — 3 checks. ai-kit issue #69 (parent #52).
    # All warn-only; never raise to error. Each gated on its preconditions
    # so local-only / fresh / non-admin / non-git repos see no false drift.
    # ------------------------------------------------------------------
    echo ""
    echo "Single-dev drift"
    if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
      info "skipped — not a git repo"
    else
      _gh_remote_url="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
      case "$_gh_remote_url" in
        *github.com*) _is_gh=true ;;
        *) _is_gh=false ;;
      esac

      # Check 1 — PR template absent (GH repos only).
      if [ "$_is_gh" = true ]; then
        _pr_tpl_found=false
        for p in "$TARGET/.github/PULL_REQUEST_TEMPLATE.md" \
                 "$TARGET/.github/pull_request_template.md" \
                 "$TARGET/docs/pull_request_template.md"; do
          [ -f "$p" ] && _pr_tpl_found=true
        done
        if [ "$_pr_tpl_found" = false ]; then
          warn "PR template missing at any honored .github path — run /ai:setup-gh-workflow"
        else
          ok "PR template present"
        fi
      else
        info "PR template check skipped — non-GitHub remote"
      fi

      # Check 2 — branch-protection off (requires gh + admin scope).
      if [ "$_is_gh" = true ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        _owner_repo="$(printf '%s' "$_gh_remote_url" | sed -E 's#.*github\.com[:/]([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')"
        _default_branch="$(gh api "repos/$_owner_repo" --jq .default_branch 2>/dev/null || echo "master")"
        # 200 → protected; 404 → not protected (drift); 403 → not admin (silent skip).
        _http_out="$(gh api "repos/$_owner_repo/branches/$_default_branch/protection" 2>&1 >/dev/null || true)"
        case "$_http_out" in
          *"HTTP 404"*|*"Not Found"*|*"404:"*)
            warn "branch-protection off on $_owner_repo branch $_default_branch — run /ai:setup-gh-workflow"
            ;;
          *"HTTP 403"*|*"Forbidden"*|*"403:"*)
            info "branch-protection check skipped — not repo admin"
            ;;
          "")
            ok "branch-protection enabled on $_default_branch"
            ;;
          *)
            info "branch-protection check inconclusive ($_http_out)"
            ;;
        esac
      elif [ "$_is_gh" = true ]; then
        info "branch-protection check skipped — gh CLI not authenticated"
      else
        info "branch-protection check skipped — non-GitHub remote"
      fi

      # Check 3 — single-committer in last 30 days (>5 commits gate).
      if [ "$_is_gh" = true ]; then
        _commit_count="$(git -C "$TARGET" log --since=30.days --oneline 2>/dev/null | wc -l | tr -d ' ')"
        if [ "${_commit_count:-0}" -ge 5 ]; then
          _author_count="$(git -C "$TARGET" log --since=30.days --format=%ae 2>/dev/null | sort -u | wc -l | tr -d ' ')"
          if [ "${_author_count:-0}" -le 1 ]; then
            warn "single-committer in last 30d ($_commit_count commits, 1 author) — document reviewer cadence in CLAUDE.md (e.g. AI-as-reviewer + weekly human sweep)"
          else
            ok "$_author_count distinct committers in last 30d"
          fi
        else
          info "committer check skipped — fewer than 5 commits in last 30d"
        fi
      fi
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
