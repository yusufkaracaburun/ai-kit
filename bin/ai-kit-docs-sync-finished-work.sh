#!/usr/bin/env bash
# Detect finished-work cleanup candidates — merged branches + closable issues.
#
# Scope (locked from #88 grilling — DO NOT EXPAND):
#   * Local merged branches: `git branch --merged <default>`, excluding default
#     branch, HEAD, and the currently-checked-out branch.
#   * Closable issues: merged PRs whose body contains
#     `closes #N` / `fixes #N` / `resolves #N` (strict regex, NO fuzzy match).
#     Cross-reference each #N — if the referenced issue is still `open`,
#     it is "closable".
#
# Default branch detection: tries `git remote show origin`'s HEAD branch,
# falls back to `master` then `main`. Auto-skips when the repo is not a
# git repo or when no default branch can be determined.
#
# Fix flow (two-step, per-op safety per #88):
#   - Local branch delete  → group-confirmable (`git branch -d <name>`).
#   - Remote branch delete → INDIVIDUAL y/N per branch (`git push origin --delete`).
#   - `gh issue close`     → INDIVIDUAL y/N per issue.
#
# Exit codes:
#   0 — nothing found OR not a git repo OR no default branch detected
#   1 — one or more findings
#   2 — error
set -uo pipefail

PROJECT_PATH=""
NO_PROMPT=0

for arg in "$@"; do
  case "$arg" in
    --no-prompt) NO_PROMPT=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "finished-work: project path does not exist: $PROJECT_PATH" >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

[ -t 0 ] || NO_PROMPT=1

# Git repo?
if ! git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
  echo "finished-work: not a git repo — skipped."
  exit 0
fi

# Detect default branch.
DEFAULT_BRANCH=""
if remote_head="$(git -C "$PROJECT_PATH" remote show origin 2>/dev/null | awk '/HEAD branch/ { print $NF }')"; then
  if [ -n "$remote_head" ] && [ "$remote_head" != "(unknown)" ]; then
    DEFAULT_BRANCH="$remote_head"
  fi
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  for cand in master main; do
    if git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$cand"; then
      DEFAULT_BRANCH="$cand"
      break
    fi
  done
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  echo "finished-work: no default branch detected (no remote origin + no master/main locally) — skipped."
  exit 0
fi

CURRENT_BRANCH="$(git -C "$PROJECT_PATH" branch --show-current 2>/dev/null || echo "")"

# Local merged branches. Strip leading `*` and whitespace.
MERGED_BRANCHES=()
while IFS= read -r b; do
  # git prefixes a branch checked out in a LINKED WORKTREE with `+`. Such a
  # branch is live work, not a cleanup candidate — and the old strip left the
  # marker in the name, so it was reported as `+ <branch>` and the suggested
  # `git branch -d` would have failed on it anyway. (#145)
  case "$b" in
    "+ "*) continue ;;
  esac
  b="$(printf '%s' "$b" | sed -e 's/^[* ]\{1,\}//' -e 's/[[:space:]]\{1,\}$//')"
  [ -z "$b" ] && continue
  case "$b" in
    "$DEFAULT_BRANCH") continue ;;
    "$CURRENT_BRANCH") continue ;;
    *"detached"*|*HEAD*) continue ;;
  esac
  MERGED_BRANCHES+=("$b")
done < <(git -C "$PROJECT_PATH" branch --merged "$DEFAULT_BRANCH" 2>/dev/null)

# Closable issues via merged PRs.
# Requires `gh` and a GitHub remote; warn + skip if missing.
CLOSABLE_ISSUES=()  # entries like `<issue#>|<pr#>|<issue-title>|<pr-url>`
GH_AVAILABLE=1
if ! command -v gh >/dev/null 2>&1; then
  GH_AVAILABLE=0
elif ! gh auth status >/dev/null 2>&1; then
  GH_AVAILABLE=0
fi

if [ "$GH_AVAILABLE" -eq 1 ]; then
  # List recently merged PRs (limit to last 50 — enough signal, cheap call).
  pr_json="$(gh -R "$PROJECT_PATH" pr list --state merged --limit 50 --json number,body,url 2>/dev/null || true)"
  if [ -n "$pr_json" ] && [ "$pr_json" != "[]" ]; then
    # Extract `closes #N`, `fixes #N`, `resolves #N` (case-insensitive verb).
    # Strict regex: verb + whitespace + `#` + digits, with a word-boundary
    # before the verb so "addresses #N" / "see #N" / "for #N" don't match.
    refs="$(printf '%s' "$pr_json" | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
pat = re.compile(r"(?<![A-Za-z])(?:closes|fixes|resolves)\s+#(\d+)", re.IGNORECASE)
for pr in data:
    body = pr.get("body") or ""
    pr_num = pr.get("number")
    pr_url = pr.get("url", "")
    for m in pat.finditer(body):
        print(f"{m.group(1)}|{pr_num}|{pr_url}")
')"
    if [ -n "$refs" ]; then
      while IFS='|' read -r issue_num pr_num pr_url; do
        [ -z "$issue_num" ] && continue
        state="$(gh -R "$PROJECT_PATH" issue view "$issue_num" --json state -q .state 2>/dev/null || echo "")"
        if [ "$state" = "OPEN" ]; then
          title="$(gh -R "$PROJECT_PATH" issue view "$issue_num" --json title -q .title 2>/dev/null || echo "")"
          CLOSABLE_ISSUES+=("${issue_num}|${pr_num}|${title}|${pr_url}")
        fi
      done <<< "$refs"
    fi
  fi
fi

TOTAL=$(( ${#MERGED_BRANCHES[@]} + ${#CLOSABLE_ISSUES[@]} ))

if [ "$TOTAL" -eq 0 ]; then
  echo "finished-work: 0 findings — clean (default branch: $DEFAULT_BRANCH)."
  exit 0
fi

echo "finished-work: $TOTAL finding(s) (default branch: $DEFAULT_BRANCH):"
echo ""

if [ "${#MERGED_BRANCHES[@]}" -gt 0 ]; then
  echo "  Local merged branches (${#MERGED_BRANCHES[@]}):"
  for b in "${MERGED_BRANCHES[@]}"; do
    last="$(git -C "$PROJECT_PATH" log -1 --format='%h %s' "$b" 2>/dev/null || echo '<unknown>')"
    printf '    %s — last: %s\n' "$b" "$last"
  done
  echo ""
fi

if [ "${#CLOSABLE_ISSUES[@]}" -gt 0 ]; then
  echo "  Closable issues (${#CLOSABLE_ISSUES[@]} — merged PR explicitly closes/fixes/resolves):"
  for row in "${CLOSABLE_ISSUES[@]}"; do
    IFS='|' read -r issue_num pr_num title pr_url <<< "$row"
    printf '    #%s — %s (closed by PR #%s, merged: %s)\n' "$issue_num" "$title" "$pr_num" "$pr_url"
  done
  echo ""
fi

if [ "$GH_AVAILABLE" -eq 0 ]; then
  echo "  (gh not available or not authenticated — closable-issues sub-check skipped.)"
  echo ""
fi

# Fix prompts — local branches group-confirmable, remote + issue close per-item.
# Test escape hatch (NEVER document for production): AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1
# fakes a `y` to every prompt (used by the test suite to verify the accept path
# without a TTY). All real-world callers MUST get the explicit prompts.
TEST_AUTO_YES="${AI_KIT_DOCS_SYNC_TEST_AUTO_YES:-0}"
PROMPTS_ENABLED=0
if [ "$NO_PROMPT" -eq 0 ] || [ "$TEST_AUTO_YES" = "1" ]; then
  PROMPTS_ENABLED=1
fi

ask() {
  local prompt="$1"
  if [ "$TEST_AUTO_YES" = "1" ]; then
    echo "y"
    return 0
  fi
  printf '%s' "$prompt"
  local reply
  read -r reply || reply=""
  echo "$reply"
}

if [ "$PROMPTS_ENABLED" -eq 1 ] && [ "${#MERGED_BRANCHES[@]}" -gt 0 ]; then
  reply="$(ask "Delete ${#MERGED_BRANCHES[@]} local merged branch(es) (git branch -d)? [y/N] ")"
  if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
    for b in "${MERGED_BRANCHES[@]}"; do
      if git -C "$PROJECT_PATH" branch -d "$b" >/dev/null 2>&1; then
        echo "  deleted local: $b"
      else
        echo "  KEPT (unmerged or in-use): $b"
      fi
    done
  fi
fi

# Remote branch delete + issue close are individual y/N per item. Never batched.
if [ "$PROMPTS_ENABLED" -eq 1 ] && [ "${#MERGED_BRANCHES[@]}" -gt 0 ]; then
  for b in "${MERGED_BRANCHES[@]}"; do
    # Only offer if the branch still exists on origin.
    if git -C "$PROJECT_PATH" ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
      reply="$(ask "Also delete REMOTE branch origin/$b (git push origin --delete)? [y/N] ")"
      if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
        if [ "$TEST_AUTO_YES" = "1" ]; then
          echo "  (test mode — skipping actual remote push for origin/$b)"
        elif git -C "$PROJECT_PATH" push origin --delete "$b" >/dev/null 2>&1; then
          echo "  deleted remote: origin/$b"
        else
          echo "  remote delete FAILED for $b" >&2
        fi
      fi
    fi
  done
fi

if [ "$PROMPTS_ENABLED" -eq 1 ] && [ "${#CLOSABLE_ISSUES[@]}" -gt 0 ]; then
  for row in "${CLOSABLE_ISSUES[@]}"; do
    IFS='|' read -r issue_num pr_num title pr_url <<< "$row"
    reply="$(ask "Close issue #$issue_num ($title) — closed by PR #$pr_num? [y/N] ")"
    if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
      if [ "$TEST_AUTO_YES" = "1" ]; then
        echo "  (test mode — skipping actual gh issue close for #$issue_num)"
      elif gh -R "$PROJECT_PATH" issue close "$issue_num" \
             --comment "Closed by merged PR #$pr_num — closable detected via /ai:docs-sync finished-work." \
             >/dev/null 2>&1; then
        echo "  closed: #$issue_num"
      else
        echo "  close FAILED for #$issue_num" >&2
      fi
    fi
  done
fi

exit 1
