#!/usr/bin/env bash
# ai-kit installer — clone the repo and (optionally) link skills globally.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash
#
# With flags (curl-pipe form uses `bash -s --`):
#   curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh \
#     | bash -s -- --no-global --branch=master
#
# Direct invocation (after clone):
#   ./install.sh --dir ~/code/ai-kit --no-global
#
# Env-var equivalents (useful when piping):
#   AI_KIT_DIR        install location           (default: ~/.local/share/ai-kit)
#   AI_KIT_REPO       repo URL                   (default: github.com/yusufkaracaburun/ai-kit)
#   AI_KIT_BRANCH     branch/tag to checkout     (default: master)
#   AI_KIT_REF        specific commit SHA/tag    (overrides BRANCH after clone)
#   AI_KIT_NO_GLOBAL  skip bin/install-global.sh (default: 0)
#   AI_KIT_UPDATE     update existing install    (default: 0)
#   AI_KIT_QUIET      suppress progress logs     (default: 0)
set -euo pipefail

AI_KIT_DIR="${AI_KIT_DIR:-$HOME/.local/share/ai-kit}"
AI_KIT_REPO="${AI_KIT_REPO:-https://github.com/yusufkaracaburun/ai-kit.git}"
AI_KIT_BRANCH="${AI_KIT_BRANCH:-master}"
AI_KIT_REF="${AI_KIT_REF:-}"
AI_KIT_NO_GLOBAL="${AI_KIT_NO_GLOBAL:-0}"
AI_KIT_UPDATE="${AI_KIT_UPDATE:-0}"
AI_KIT_QUIET="${AI_KIT_QUIET:-0}"

usage() {
  cat <<'EOF'
ai-kit installer

Usage:
  install.sh [options]
  curl -fsSL <url>/install.sh | bash
  curl -fsSL <url>/install.sh | bash -s -- [options]

Options:
  --dir PATH        Install location (default: ~/.local/share/ai-kit)
  --repo URL        Git repo to clone (default: github.com/yusufkaracaburun/ai-kit)
  --branch NAME     Branch or tag (default: master)
  --ref SHA         Pin to a specific commit SHA or tag (overrides --branch after clone)
  --no-global       Skip linking skills into ~/.claude, ~/.agents, ~/.cursor
  --update          Update existing install (git pull --ff-only)
  --quiet           Suppress progress logs
  -h, --help        Show this message

All options also work as env vars: AI_KIT_DIR, AI_KIT_REPO, AI_KIT_BRANCH,
AI_KIT_REF, AI_KIT_NO_GLOBAL=1, AI_KIT_UPDATE=1, AI_KIT_QUIET=1.

After install, run /aikit-setup in any project (Claude Code or Cursor) to bootstrap it.
EOF
}

log() {
  [ "$AI_KIT_QUIET" = "1" ] && return 0
  printf '%s\n' "$*"
}

err() {
  printf 'Error: %s\n' "$*" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)         AI_KIT_DIR="$2"; shift 2 ;;
    --dir=*)       AI_KIT_DIR="${1#*=}"; shift ;;
    --repo)        AI_KIT_REPO="$2"; shift 2 ;;
    --repo=*)      AI_KIT_REPO="${1#*=}"; shift ;;
    --branch)      AI_KIT_BRANCH="$2"; shift 2 ;;
    --branch=*)    AI_KIT_BRANCH="${1#*=}"; shift ;;
    --ref)         AI_KIT_REF="$2"; shift 2 ;;
    --ref=*)       AI_KIT_REF="${1#*=}"; shift ;;
    --no-global)   AI_KIT_NO_GLOBAL=1; shift ;;
    --update)      AI_KIT_UPDATE=1; shift ;;
    --quiet)       AI_KIT_QUIET=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             err "unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

# Expand leading ~ in AI_KIT_DIR (string-only; case patterns don't tilde-expand).
# shellcheck disable=SC2088
case "$AI_KIT_DIR" in
  "~")   AI_KIT_DIR="$HOME" ;;
  "~/"*) AI_KIT_DIR="$HOME/${AI_KIT_DIR#"~/"}" ;;
esac

command -v git >/dev/null 2>&1 || { err "git not found in PATH"; exit 1; }

# Existing-install handling.
if [ -d "$AI_KIT_DIR/.git" ]; then
  if [ "$AI_KIT_UPDATE" = "1" ]; then
    log "Updating ai-kit at $AI_KIT_DIR (branch: $AI_KIT_BRANCH)..."
    git -C "$AI_KIT_DIR" fetch --quiet origin "$AI_KIT_BRANCH"
    git -C "$AI_KIT_DIR" checkout --quiet "$AI_KIT_BRANCH"
    git -C "$AI_KIT_DIR" pull --quiet --ff-only origin "$AI_KIT_BRANCH"
  else
    log "ai-kit already installed at $AI_KIT_DIR"
    log "  (rerun with --update or AI_KIT_UPDATE=1 to pull latest)"
  fi
elif [ -e "$AI_KIT_DIR" ]; then
  err "$AI_KIT_DIR exists but is not an ai-kit clone."
  err "Use --dir to pick another location, or remove the existing path first."
  exit 1
else
  log "Cloning ai-kit ($AI_KIT_BRANCH) -> $AI_KIT_DIR..."
  parent="$(dirname "$AI_KIT_DIR")"
  mkdir -p "$parent"
  git clone --quiet --branch "$AI_KIT_BRANCH" --single-branch "$AI_KIT_REPO" "$AI_KIT_DIR"
fi

# Optional pin to a specific ref (tag or SHA).
if [ -n "$AI_KIT_REF" ]; then
  log "Checking out ref: $AI_KIT_REF"
  git -C "$AI_KIT_DIR" fetch --quiet --tags origin
  git -C "$AI_KIT_DIR" checkout --quiet "$AI_KIT_REF"
fi

# Sanity-check we actually have an ai-kit clone.
if [ ! -f "$AI_KIT_DIR/VERSION" ] || [ ! -d "$AI_KIT_DIR/workflow/skills" ]; then
  err "$AI_KIT_DIR does not look like an ai-kit checkout (missing VERSION or workflow/skills)."
  exit 1
fi

# Persist the root so resolve_ai_kit_root finds it from any cwd.
mkdir -p "$HOME/.config/ai-kit"
printf '%s\n' "$AI_KIT_DIR" > "$HOME/.config/ai-kit/root"

if [ "$AI_KIT_NO_GLOBAL" = "1" ]; then
  log "Skipping global skill install (--no-global)."
else
  log ""
  log "Linking skills globally..."
  if [ "$AI_KIT_QUIET" = "1" ]; then
    "$AI_KIT_DIR/bin/install-global.sh" >/dev/null
  else
    "$AI_KIT_DIR/bin/install-global.sh"
  fi
fi

VERSION="$(tr -d '[:space:]' < "$AI_KIT_DIR/VERSION")"

log ""
log "================================================================"
log "ai-kit ${VERSION} installed at: $AI_KIT_DIR"
if [ "$AI_KIT_NO_GLOBAL" = "1" ]; then
  log "Global skills:   skipped (--no-global)"
else
  log "Global skills:   linked into ~/.claude, ~/.agents, ~/.cursor"
fi
log ""
log "Next steps:"
log "  1. Open any project:   cd /path/to/project"
log "  2. Bootstrap it:       $AI_KIT_DIR/bin/bootstrap-project.sh ."
log "  3. Run /aikit-setup in Claude Code or Cursor"
log ""
log "Docs:  $AI_KIT_DIR/README.md"
log "Doctor: $AI_KIT_DIR/bin/ai-kit-doctor.sh"
log "================================================================"
