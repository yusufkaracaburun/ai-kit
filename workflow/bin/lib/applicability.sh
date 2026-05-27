#!/usr/bin/env bash
# Reusable applicability checks for ai-kit cross-cues (per #88 / #95).
#
# Each function takes a project path and returns 0 (applicable) or 1
# (not applicable). Designed to be < 50ms per call on a typical repo —
# no recursion past the first hit, no `git` calls unless cheap.
#
# Source this file from other scripts:
#   source "$(dirname "$0")/lib/applicability.sh"
#   is_docs_sync_applicable "$PROJECT_PATH" && echo "show docs-sync nudge"

# /ai:docs-sync applies if ANY of:
#   - `docs/` directory exists
#   - any `*.md` file in the repo (excluding common vendor / build paths)
#   - more than one local branch (i.e., refs/heads/ has entries other than the default)
is_docs_sync_applicable() {
  local project_path="${1:-$PWD}"
  [ -d "$project_path" ] || return 1

  if [ -d "$project_path/docs" ]; then
    return 0
  fi

  # Cheap markdown detection: bail on first hit.
  local first_md
  first_md="$(find "$project_path" \
    -type d \( -name .git -o -name node_modules -o -name vendor \
              -o -name dist -o -name build -o -name .next -o -name .turbo \) -prune -o \
    -type f -name '*.md' -print 2>/dev/null | head -1)"
  if [ -n "$first_md" ]; then
    return 0
  fi

  # Local branch presence beyond the default.
  if [ -d "$project_path/.git" ] || git -C "$project_path" rev-parse --git-dir >/dev/null 2>&1; then
    local branch_count
    branch_count="$(git -C "$project_path" for-each-ref --count=2 --format='%(refname)' refs/heads/ 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${branch_count:-0}" -gt 1 ]; then
      return 0
    fi
  fi

  return 1
}

# /ai:hygiene applies if the project has been set up via /ai:setup
# (i.e., the .ai-kit-setup marker exists).
is_hygiene_applicable() {
  local project_path="${1:-$PWD}"
  [ -d "$project_path" ] || return 1
  [ -f "$project_path/.ai-kit-setup" ]
}

# One-line cross-cue printer — used by checkpoint / ship / triage.
# Prints to stdout when the corresponding command is applicable, nothing
# otherwise. The caller decides where in its output the cue belongs.
print_docs_sync_nudge() {
  local project_path="${1:-$PWD}"
  if is_docs_sync_applicable "$project_path"; then
    echo "  /ai:docs-sync — universal content drift (dead links, repo-hygiene, finished-work cleanup)"
  fi
}

print_hygiene_nudge() {
  local project_path="${1:-$PWD}"
  if is_hygiene_applicable "$project_path"; then
    echo "  /ai:hygiene — framework wiring + install health"
  fi
}
