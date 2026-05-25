#!/usr/bin/env bash
# Install ai-kit's GitHub workflow hygiene into a target project:
#
#   1. Copy ISSUE_TEMPLATE/ (feature.md + spike.md + config.yml) into
#      TARGET/.github/ISSUE_TEMPLATE/ — Dutch by default, English via --lang en.
#   2. Copy workflows (dor-dod-enforcement.yml + auto-promote-ready.yml) into
#      TARGET/.github/workflows/. Both verbatim from naschool — battle-tested
#      DoR/DoD enforcement + auto-promote-to-Ready on project boards.
#   3. Bulk-create labels (P0-P3 priorities, epic/* placeholders, area/*
#      categories, status:in-progress) via `gh label create` — idempotent.
#   4. Detect existing GitHub Project for the repo owner; if found, resolve
#      PROJECT_NUMBER / STATUS_FIELD_ID / option IDs via `gh api graphql`
#      and substitute the AI_KIT_PROJECT_* placeholders in
#      auto-promote-ready.yml. If no board, print the manual setup steps.
#
# Idempotent: existing files are NEVER overwritten (`--force` opt-in available).
# Silent skip when target has no `gh remote` matching github.com.
#
# Usage:
#   setup-gh-workflow.sh /path/to/project              # Dutch, detect-only
#   setup-gh-workflow.sh /path/to/project --lang en    # English templates
#   setup-gh-workflow.sh /path/to/project --force      # overwrite existing files
#   setup-gh-workflow.sh /path/to/project --dry-run    # print actions, change nothing
#   setup-gh-workflow.sh /path/to/project --no-labels  # skip label creation
#   setup-gh-workflow.sh /path/to/project --no-project # skip project board detection
#   setup-gh-workflow.sh /path/to/project --quiet      # only errors

set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

LANG_VARIANT="nl"
FORCE=false
DRY_RUN=false
SKIP_LABELS=false
SKIP_PROJECT=false
SKIP_PROTECTION=false
SKIP_PR_TEMPLATE=false
QUIET=false
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    --lang=*)       LANG_VARIANT="${1#*=}"; shift ;;
    --lang)         LANG_VARIANT="$2"; shift 2 ;;
    --force)        FORCE=true; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --no-labels)    SKIP_LABELS=true; shift ;;
    --no-project)   SKIP_PROJECT=true; shift ;;
    --no-protection) SKIP_PROTECTION=true; shift ;;
    --no-pr-template) SKIP_PR_TEMPLATE=true; shift ;;
    --quiet)        QUIET=true; shift ;;
    -*)             echo "Unknown flag: $1" >&2; exit 2 ;;
    *)
      if [ -n "$TARGET" ]; then echo "Unexpected arg: $1" >&2; exit 2; fi
      TARGET="$1"; shift
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Usage: $0 /path/to/project [--lang en] [--force] [--dry-run] [--no-labels] [--no-project] [--no-protection] [--no-pr-template] [--quiet]" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

case "$LANG_VARIANT" in
  nl|en) ;;
  *) echo "Invalid --lang: $LANG_VARIANT (expected nl|en)" >&2; exit 2 ;;
esac

log() { [ "$QUIET" = true ] || echo "$*"; }
run() {
  if [ "$DRY_RUN" = true ]; then
    log "  [dry-run] $*"
  else
    "$@"
  fi
}

# ----------------------------------------------------------------------------
# 1. Detect GitHub remote — silent skip if not GitHub-hosted.
# ----------------------------------------------------------------------------
detect_gh_remote() {
  local target="$1"
  if [ ! -d "$target/.git" ] && ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    return 1
  fi
  local remote_url
  remote_url="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
  [ -z "$remote_url" ] && return 1
  case "$remote_url" in
    *github.com*) echo "$remote_url"; return 0 ;;
    *) return 1 ;;
  esac
}

GH_REMOTE_URL="$(detect_gh_remote "$TARGET" || true)"
if [ -z "$GH_REMOTE_URL" ]; then
  log "setup-gh-workflow: no GitHub remote detected at $TARGET — skipping."
  exit 0
fi

# Parse owner/repo from the remote URL — supports SSH + HTTPS forms.
OWNER_REPO="$(printf '%s' "$GH_REMOTE_URL" | sed -E 's#.*github\.com[:/]([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')"
OWNER="${OWNER_REPO%/*}"
REPO="${OWNER_REPO#*/}"
log "setup-gh-workflow: target=$TARGET remote=$OWNER/$REPO lang=$LANG_VARIANT"

# ----------------------------------------------------------------------------
# 2. Copy ISSUE_TEMPLATE/ — Dutch by default, English via --lang en.
# ----------------------------------------------------------------------------
TEMPLATE_DIR="$AIKIT/context/templates/github"
[ -d "$TEMPLATE_DIR" ] || { echo "Templates missing: $TEMPLATE_DIR" >&2; exit 1; }

mkdir -p "$TARGET/.github/ISSUE_TEMPLATE" "$TARGET/.github/workflows"

copy_template() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && [ "$FORCE" = false ]; then
    log "  skip (exists): ${dst#"$TARGET"/}"
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    log "  [dry-run] copy ${src#"$AIKIT"/} → ${dst#"$TARGET"/}"
    return 0
  fi
  cp "$src" "$dst"
  log "  wrote ${dst#"$TARGET"/}"
}

case "$LANG_VARIANT" in
  nl)
    copy_template "$TEMPLATE_DIR/ISSUE_TEMPLATE/feature.md" "$TARGET/.github/ISSUE_TEMPLATE/feature.md"
    copy_template "$TEMPLATE_DIR/ISSUE_TEMPLATE/spike.md"   "$TARGET/.github/ISSUE_TEMPLATE/spike.md"
    ;;
  en)
    copy_template "$TEMPLATE_DIR/ISSUE_TEMPLATE/feature.en.md" "$TARGET/.github/ISSUE_TEMPLATE/feature.md"
    copy_template "$TEMPLATE_DIR/ISSUE_TEMPLATE/spike.en.md"   "$TARGET/.github/ISSUE_TEMPLATE/spike.md"
    ;;
esac

# config.yml uses placeholder AI_KIT_PROJECT_BOARD_URL — substitute later
# once project board is detected. For now copy with placeholder intact.
copy_template "$TEMPLATE_DIR/ISSUE_TEMPLATE/config.yml" "$TARGET/.github/ISSUE_TEMPLATE/config.yml"

# ----------------------------------------------------------------------------
# 3. Copy workflows. dor-dod-enforcement.yml is verbatim; auto-promote-ready.yml
#    needs placeholder substitution after project-board detection.
# ----------------------------------------------------------------------------
copy_template "$TEMPLATE_DIR/workflows/dor-dod-enforcement.yml" "$TARGET/.github/workflows/dor-dod-enforcement.yml"
copy_template "$TEMPLATE_DIR/workflows/auto-promote-ready.yml"  "$TARGET/.github/workflows/auto-promote-ready.yml"

# ----------------------------------------------------------------------------
# 4. Bulk-create labels via `gh label create`.
#    Idempotent: --force updates color/description on existing labels.
# ----------------------------------------------------------------------------
if [ "$SKIP_LABELS" = false ]; then
  if ! command -v gh >/dev/null 2>&1; then
    log "gh CLI not found — skipping label creation. Install: https://cli.github.com/"
  elif ! gh auth status >/dev/null 2>&1; then
    log "gh not authenticated — skipping label creation. Run: gh auth login"
  else
    log "creating/updating labels via gh label create --force"
    LABELS_JSON="$TEMPLATE_DIR/labels.json"
    while IFS=$'\t' read -r name color description; do
      [ -z "$name" ] && continue
      run gh label create "$name" \
        --color "$color" \
        --description "$description" \
        --repo "$OWNER/$REPO" \
        --force >/dev/null 2>&1 || log "  warn: label create failed for '$name'"
      log "  label: $name"
    done < <(python3 -c "
import json, sys
for l in json.load(open('$LABELS_JSON')):
    print(l['name'] + '\t' + l['color'] + '\t' + l['description'])
")
  fi
fi

# ----------------------------------------------------------------------------
# 5. Detect existing project board, resolve IDs, substitute placeholders.
# ----------------------------------------------------------------------------
if [ "$SKIP_PROJECT" = false ]; then
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    log "gh CLI unavailable or unauthenticated — skipping project-board detection."
    log "  Manual steps after authenticating:"
    log "    gh project create --owner $OWNER --title \"$REPO\""
    log "    Then re-run: $0 $TARGET --lang $LANG_VARIANT"
  else
    log "detecting GitHub Project for owner=$OWNER"
    # List user projects; pick first matching the repo name, else the most recent.
    PROJECT_JSON="$(gh project list --owner "$OWNER" --format json 2>/dev/null || echo '{"projects":[]}')"
    PROJECT_NUMBER="$(python3 -c "
import json, sys, re
try:
    data = json.loads('''$PROJECT_JSON''')
except Exception:
    sys.exit(0)
projects = data.get('projects', [])
# Prefer a project whose title contains the repo name; else most recent
match = next((p for p in projects if '$REPO'.lower() in (p.get('title') or '').lower()), None)
if not match and projects:
    match = projects[0]
if match:
    print(match.get('number', ''))
" 2>/dev/null || true)"

    if [ -z "$PROJECT_NUMBER" ]; then
      log "  no existing project board found for $OWNER"
      log "  Create one with:"
      log "    gh project create --owner $OWNER --title \"$REPO board\""
      log "  Add a Status field with options Todo / Ready / In Progress / Done."
      log "  Then re-run: $0 $TARGET --lang $LANG_VARIANT"
      log "  Also add a repo secret PROJECT_TOKEN (PAT with 'project' + 'repo' scope)."
    else
      log "  found project #$PROJECT_NUMBER for owner $OWNER"
      # Fetch Status field + Todo + Ready option IDs.
      FIELDS_JSON="$(gh api graphql -f query='
        query($owner: String!, $number: Int!) {
          user(login: $owner) {
            projectV2(number: $number) {
              id
              field(name: "Status") {
                ... on ProjectV2SingleSelectField {
                  id
                  options { id name }
                }
              }
            }
          }
        }
      ' -F owner="$OWNER" -F number="$PROJECT_NUMBER" 2>/dev/null || echo '{}')"
      RESOLVED="$(python3 -c "
import json, sys
try:
    d = json.loads('''$FIELDS_JSON''')
except Exception:
    sys.exit(0)
pv = (d.get('data') or {}).get('user', {}).get('projectV2') or {}
field = pv.get('field') or {}
if not field.get('id'):
    sys.exit(0)
ready = next((o for o in field.get('options', []) if o['name'].lower() == 'ready'), None)
todo  = next((o for o in field.get('options', []) if o['name'].lower() == 'todo'),  None)
if not (ready and todo):
    sys.exit(0)
print(f\"{field['id']}|{ready['id']}|{todo['id']}\")
" 2>/dev/null || true)"

      if [ -n "$RESOLVED" ]; then
        IFS='|' read -r STATUS_FIELD_ID READY_OPTION_ID TODO_OPTION_ID <<<"$RESOLVED"
        WORKFLOW="$TARGET/.github/workflows/auto-promote-ready.yml"
        CONFIG_YML="$TARGET/.github/ISSUE_TEMPLATE/config.yml"
        PROJECT_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
        if [ "$DRY_RUN" = true ]; then
          log "  [dry-run] would substitute PROJECT_NUMBER=$PROJECT_NUMBER OWNER=$OWNER STATUS_FIELD_ID=$STATUS_FIELD_ID READY=$READY_OPTION_ID TODO=$TODO_OPTION_ID"
        else
          # macOS-portable sed via python (avoids -i differences).
          python3 - "$WORKFLOW" <<PYEOF
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('AI_KIT_PROJECT_NUMBER',  '$PROJECT_NUMBER')
s = s.replace('AI_KIT_PROJECT_OWNER',   '$OWNER')
s = s.replace('AI_KIT_STATUS_FIELD_ID', '$STATUS_FIELD_ID')
s = s.replace('AI_KIT_READY_OPTION_ID', '$READY_OPTION_ID')
s = s.replace('AI_KIT_TODO_OPTION_ID',  '$TODO_OPTION_ID')
open(p, 'w').write(s)
PYEOF
          python3 - "$CONFIG_YML" <<PYEOF
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('AI_KIT_PROJECT_BOARD_URL', '$PROJECT_URL')
open(p, 'w').write(s)
PYEOF
          log "  substituted project IDs into auto-promote-ready.yml + config.yml"
        fi
        log "  PROJECT_TOKEN secret required — add via:"
        log "    gh secret set PROJECT_TOKEN --repo $OWNER/$REPO"
        log "    (use a PAT with 'project' + 'repo' scope — GITHUB_TOKEN cannot touch Projects v2)"
      else
        log "  could not resolve Status field on project #$PROJECT_NUMBER — verify the board has a Status field with Todo/Ready/In Progress/Done options."
      fi
    fi
  fi
fi

# ----------------------------------------------------------------------------
# 4. Scaffold PR template — ai-kit issue #66 (parent #52).
#    Idempotent: skip if any of the three GitHub-honored paths already populated.
# ----------------------------------------------------------------------------
scaffold_pr_template() {
  local target="$1"
  local src="$AIKIT/context/templates/github/PULL_REQUEST_TEMPLATE.md"
  local candidates=(
    "$target/.github/PULL_REQUEST_TEMPLATE.md"
    "$target/.github/pull_request_template.md"
    "$target/docs/pull_request_template.md"
  )
  for p in "${candidates[@]}"; do
    if [ -f "$p" ]; then
      log "PR template: already present at ${p#$target/} — skip"
      return 0
    fi
  done
  [ -f "$src" ] || { log "PR template: source missing ($src) — skip"; return 0; }
  if [ "$DRY_RUN" = true ]; then
    log "  [dry-run] would scaffold PR template at .github/PULL_REQUEST_TEMPLATE.md"
    return 0
  fi
  mkdir -p "$target/.github"
  cp "$src" "$target/.github/PULL_REQUEST_TEMPLATE.md"
  log "PR template: scaffolded at .github/PULL_REQUEST_TEMPLATE.md"
}

# ----------------------------------------------------------------------------
# 5. Apply branch protection — hybrid: gh api PUT, 403 → checklist fallback.
#    ai-kit issue #66. Drift = warn, never break (exit 0 even on 403).
# ----------------------------------------------------------------------------
apply_branch_protection() {
  local owner="$1" repo="$2"
  local default_branch
  default_branch="$(gh api "repos/$owner/$repo" --jq .default_branch 2>/dev/null || echo "master")"
  local payload
  payload=$(cat <<JSON
{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
JSON
)
  local fallback_cmd="gh api -X PUT repos/$owner/$repo/branches/$default_branch/protection --input - <<EOF
$payload
EOF"
  if [ "$DRY_RUN" = true ]; then
    log "  [dry-run] branch-protection payload for $owner/$repo branch $default_branch:"
    log "    $payload"
    log "  [dry-run] fallback command if PUT returns 403:"
    log "    $fallback_cmd"
    return 0
  fi
  if printf '%s' "$payload" | gh api -X PUT "repos/$owner/$repo/branches/$default_branch/protection" --input - >/dev/null 2>&1; then
    log "branch-protection: applied on $owner/$repo branch $default_branch (≥1 approving review)"
    return 0
  fi
  # PUT failed (most commonly 403 = insufficient scope / not repo admin).
  # Drift = warn, never break — print the exact fallback command.
  log "branch-protection: PUT failed (403 likely — admin scope required)."
  log "  Fallback: an admin can run the following from this repo:"
  log ""
  log "    $fallback_cmd"
  log ""
  log "  See ai-kit issue #52 for the 2-dev default rationale."
  return 0
}

if [ "$SKIP_PR_TEMPLATE" = false ]; then
  scaffold_pr_template "$TARGET"
fi

if [ "$SKIP_PROTECTION" = false ]; then
  apply_branch_protection "$OWNER" "$REPO"
fi

log "setup-gh-workflow: done."
