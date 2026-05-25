#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== setup-gh-workflow-protection ==="
# Section: setup-gh-workflow-protection
# Verifies setup-gh-workflow.sh scaffolds a PR template + applies branch-
# protection via `gh api PUT`, with a 403 → checklist fallback. See ai-kit
# issue #66 (parent #52).

SCRIPT="$AIKIT/bin/setup-gh-workflow.sh"
TMPL="$AIKIT/context/templates/github/PULL_REQUEST_TEMPLATE.md"

# --- 1. PR template ships in the catalog --------------------------------
assert "PR template exists at context/templates/github/" '[ -f "$TMPL" ]'
assert "PR template includes DoR / DoD checkboxes" \
  'grep -qi "DoR\|Definition of Ready" "$TMPL" && grep -qi "DoD\|Definition of Done" "$TMPL"'
assert "PR template uses checkbox markdown" 'grep -q "^- \[ \]" "$TMPL"'

# --- 2. Script has the new functions / flags ----------------------------
assert "script knows --no-protection flag" 'grep -q "\-\-no-protection" "$SCRIPT"'
assert "script knows --no-pr-template flag" 'grep -q "\-\-no-pr-template" "$SCRIPT"'
assert "script has apply_branch_protection function" 'grep -q "apply_branch_protection" "$SCRIPT"'
assert "script has scaffold_pr_template function" 'grep -q "scaffold_pr_template" "$SCRIPT"'
assert "script issues gh api PUT for branches protection" \
  'grep -qE "gh api -X PUT .*branches/.*protection|gh api .*-X PUT .*protection" "$SCRIPT"'
assert "script handles 403 with fallback message" \
  'grep -qiE "403|fallback|insufficient|admin" "$SCRIPT"'

# --- 3. Hybrid behaviour via stub gh ------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stub-bin" "$TMP/project/.git"
# Minimal fake git repo so the script's `gh remote` checks see a github URL.
( cd "$TMP/project" && git init -q && git remote add origin git@github.com:fake/proj.git )

# --- 3a. Mocked 200 PUT path ---
cat > "$TMP/stub-bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"remote"*) echo "git@github.com:fake/proj.git"; exit 0 ;;
  *"api repos/fake/proj"*"--jq .default_branch"*) echo "master"; exit 0 ;;
  *"api -X PUT"*"branches/"*"protection"*) echo '{"required_pull_request_reviews":{"required_approving_review_count":1}}'; exit 0 ;;
  *"label"*) exit 0 ;;
  *"api graphql"*) echo '{"data":null}'; exit 0 ;;
  *"auth status"*) exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$TMP/stub-bin/gh"
OUT_200="$(PATH="$TMP/stub-bin:$PATH" bash "$SCRIPT" "$TMP/project" --dry-run --no-labels --no-project 2>&1 || true)"
assert "dry-run emits the protection JSON payload" \
  'echo "$OUT_200" | grep -qE "required_pull_request_reviews|required_approving_review_count"'
assert "dry-run mentions PR-template scaffold action" \
  'echo "$OUT_200" | grep -qi "PULL_REQUEST_TEMPLATE\|PR template"'

# --- 3b. Mocked 403 fallback path ---
cat > "$TMP/stub-bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"remote"*) echo "git@github.com:fake/proj.git"; exit 0 ;;
  *"api repos/fake/proj"*"--jq .default_branch"*) echo "master"; exit 0 ;;
  *"api -X PUT"*"branches/"*"protection"*) echo "HTTP 403: Forbidden — admin scope required" >&2; exit 1 ;;
  *"label"*) exit 0 ;;
  *"api graphql"*) echo '{"data":null}'; exit 0 ;;
  *"auth status"*) exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$TMP/stub-bin/gh"
OUT_403="$(PATH="$TMP/stub-bin:$PATH" bash "$SCRIPT" "$TMP/project" --no-labels --no-project 2>&1 || true)"
ACTUAL_EXIT=$?
assert "403 fallback exits 0 (drift = warn, not break)" '[ "$ACTUAL_EXIT" -eq 0 ]'
assert "403 path prints the fallback gh api command" \
  'echo "$OUT_403" | grep -qE "gh api .*protection"'

# --- 4. PR template idempotent skip --------------------------------------
mkdir -p "$TMP/project/.github"
echo "EXISTING USER CONTENT" > "$TMP/project/.github/PULL_REQUEST_TEMPLATE.md"
PATH="$TMP/stub-bin:$PATH" bash "$SCRIPT" "$TMP/project" --no-labels --no-project --no-protection >/dev/null 2>&1 || true
assert "existing PR template preserved verbatim (idempotent skip)" \
  'grep -q "EXISTING USER CONTENT" "$TMP/project/.github/PULL_REQUEST_TEMPLATE.md"'

print_summary_and_exit
