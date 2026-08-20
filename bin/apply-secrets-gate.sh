#!/usr/bin/env bash
# Wire a project's secret-prevention gate.
#
# Two halves, deliberately asymmetric.
#
# CI is emitted unconditionally. It is the only uniform surface — one file,
# one shape, no detection — and it is the half nothing bypasses.
#
# Pre-commit is appended only to a mechanism the project already runs, and a
# mechanism is never introduced. Six real projects surveyed for #120 use four
# different ones (husky, a tracked hooks directory, plain .git/hooks, none)
# and not one uses the pre-commit framework, so emitting its config would add
# a fifth mechanism plus a Python dependency to repositories that already
# have a working hook. Where nothing exists we print the command and write
# nothing: standing up a hook framework for a single guard is a decision the
# maintainer makes deliberately.
#
# Idempotent. Existing files are never overwritten without --force, and the
# guard line is appended at most once.
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

GUARD='gitleaks protect --staged --no-banner --redact'

usage() {
  echo "Usage: $0 /path/to/project [--force]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
TARGET="$(cd "$1" 2>/dev/null && pwd)" || { echo "Not a directory: $1" >&2; exit 1; }
shift

FORCE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    -h | --help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "apply-secrets-gate: $TARGET is not a git repository." >&2
  exit 1
}

# ---------------------------------------------------------------------------
# 1. CI — unconditional.
# ---------------------------------------------------------------------------
SRC="$AIKIT/context/templates/github/workflows/gitleaks.yml"
[ -f "$SRC" ] || { echo "Template missing: $SRC" >&2; exit 1; }

DST="$TARGET/.github/workflows/gitleaks.yml"
mkdir -p "$TARGET/.github/workflows"
if [ -f "$DST" ] && [ "$FORCE" = false ]; then
  echo "  skip (exists): .github/workflows/gitleaks.yml — pass --force to replace"
else
  cp "$SRC" "$DST"
  echo "  wrote .github/workflows/gitleaks.yml"
fi

# ---------------------------------------------------------------------------
# 2. Pre-commit — only into a mechanism that is already there.
# ---------------------------------------------------------------------------
HOOKS_PATH="$(git -C "$TARGET" config --get core.hooksPath 2>/dev/null || true)"

# A configured hooks path — or a husky directory — IS the mechanism, whether
# or not a pre-commit file has been written into it yet. Using it is not the
# same as introducing it, so a project that opted into husky and has not
# written this particular hook gets the guard rather than a message telling
# it that it has no mechanism, which would simply be untrue.
if [ -n "$HOOKS_PATH" ] || [ -d "$TARGET/.husky" ]; then
  case "$HOOKS_PATH$([ -d "$TARGET/.husky" ] && echo .husky)" in
    # husky points core.hooksPath at its internal .husky/_ shim, but the hook
    # a maintainer edits — and the one that survives a husky reinstall — is
    # .husky/pre-commit one level up.
    *.husky*) MECHANISM="husky"; HOOK="$TARGET/.husky/pre-commit" ;;
    *) MECHANISM="tracked hooks directory"; HOOK="$TARGET/$HOOKS_PATH/pre-commit" ;;
  esac
  MECHANISM_EXISTS=true
else
  # No hooks path and no husky: the only candidate is the default directory,
  # and if nothing lives there the project has no pre-commit story at all.
  MECHANISM="plain .git/hooks"
  HOOK="$TARGET/.git/hooks/pre-commit"
  MECHANISM_EXISTS=false
fi

if [ ! -f "$HOOK" ] && [ "$MECHANISM_EXISTS" = true ]; then
  mkdir -p "$(dirname "$HOOK")"
  printf '#!/bin/sh\n' > "$HOOK"
  chmod +x "$HOOK"
fi

if [ ! -f "$HOOK" ]; then
  echo "  no pre-commit mechanism found — nothing written."
  echo "  This project has no pre-commit hook to extend, and introducing one"
  echo "  is your call rather than a side effect of this command. To add the"
  echo "  guard yourself, put this in whichever hook you adopt:"
  echo ""
  echo "      $GUARD"
  echo ""
  echo "  CI already covers the bypassable gap either way."
  exit 0
fi

if grep -qF 'gitleaks protect' "$HOOK" 2>/dev/null; then
  echo "  pre-commit ($MECHANISM): guard already present — left alone"
  exit 0
fi

printf '\n# Added by ai-kit: block staged secrets before they reach a commit.\n%s\n' "$GUARD" >> "$HOOK"
chmod +x "$HOOK" 2>/dev/null || true
echo "  pre-commit ($MECHANISM): guard appended to ${HOOK#"$TARGET"/}"
