#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== single-dev-drift ==="
# Section: single-dev-drift
# ai-kit issue #69 (parent #52). doctor emits 3 single-dev drift checks
# under matching conditions, skips gracefully when gating preconditions
# don't hold. hygiene inherits via its invocation of doctor.

DOCTOR="$AIKIT/bin/ai-kit-doctor.sh"
HYGIENE="$AIKIT/bin/ai-kit-hygiene.sh"

assert "doctor script exists" '[ -f "$DOCTOR" ]'
assert "hygiene script exists" '[ -f "$HYGIENE" ]'
assert "hygiene invokes doctor (no duplicate impl)" 'grep -q "ai-kit-doctor.sh" "$HYGIENE"'

# Static checks — strings exist in doctor.
assert "doctor has Single-dev drift section header" \
  'grep -qE "Single[- ]dev drift|2[- ]dev drift" "$DOCTOR"'
assert "doctor checks PR-template absence" \
  'grep -qE "PULL_REQUEST_TEMPLATE" "$DOCTOR"'
assert "doctor checks branch-protection via gh api" \
  'grep -qE "branches/.*protection|branch.protection" "$DOCTOR"'
assert "doctor checks single-committer in 30d window" \
  'grep -qE "30.days|since.*30 days" "$DOCTOR"'

# Behaviour — run doctor against a fixture project.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stub-bin"

# --- 1. Local-only project (no GH remote): no GH drift fires ---
mkdir -p "$TMP/projA"
( cd "$TMP/projA" && git init -q -b master && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m "init" )
OUT_A="$(PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projA" 2>&1 || true)"
assert "non-GH repo: no PR-template drift fires" \
  '! echo "$OUT_A" | grep -qE "PULL_REQUEST_TEMPLATE.*missing|PR template.*missing"'
assert "non-GH repo: no branch-protection drift fires" \
  '! echo "$OUT_A" | grep -qE "branch-protection.*off|branch.protection.*off"'

# --- 2. GH repo with stub gh — PR template missing, branch-protection 404,
#        committer count > 1 (so committer check should NOT fire). ---
mkdir -p "$TMP/projB"
( cd "$TMP/projB" && git init -q -b master && \
  git remote add origin git@github.com:fake/projB.git && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m c1 && \
  git -c user.email=b@x -c user.name=B commit -q --allow-empty -m c2 && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m c3 && \
  git -c user.email=b@x -c user.name=B commit -q --allow-empty -m c4 && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m c5 && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m c6 )
cat > "$TMP/stub-bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"auth status"*) exit 0 ;;
  *"api repos/fake/projB"*"protection"*) echo "HTTP 404" >&2; exit 1 ;;
  *"api repos/fake/projB"*) echo '{"default_branch":"master"}'; exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$TMP/stub-bin/gh"
OUT_B="$(PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projB" 2>&1 || true)"
assert "GH repo without PR-template: drift fires" \
  'echo "$OUT_B" | grep -qiE "PULL_REQUEST_TEMPLATE|PR template"'
assert "GH repo without branch-protection: drift fires" \
  'echo "$OUT_B" | grep -qiE "branch.protection"'
assert "GH repo with >1 committer in 30d: single-committer drift does NOT fire" \
  '! echo "$OUT_B" | grep -qiE "single.committer"'

# --- 3. GH repo with single committer in last 30d (>5 commits, all one author) ---
mkdir -p "$TMP/projC"
( cd "$TMP/projC" && git init -q -b master && \
  git remote add origin git@github.com:fake/projC.git && \
  for i in 1 2 3 4 5 6 7; do
    git -c user.email=a@x -c user.name=A commit -q --allow-empty -m "c$i"
  done )
OUT_C="$(PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projC" 2>&1 || true)"
assert "GH repo with single committer in 30d: drift fires" \
  'echo "$OUT_C" | grep -qiE "single.committer"'

# --- 4. Fresh GH repo with <5 commits: committer check skipped ---
mkdir -p "$TMP/projD"
( cd "$TMP/projD" && git init -q -b master && \
  git remote add origin git@github.com:fake/projD.git && \
  git -c user.email=a@x -c user.name=A commit -q --allow-empty -m c1 )
OUT_D="$(PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projD" 2>&1 || true)"
assert "fresh repo (<5 commits): single-committer drift does NOT fire" \
  '! echo "$OUT_D" | grep -qiE "single.committer"'

# --- 4b. Single committer BUT a documented reviewer cadence: check passes ---
#         The warning names CLAUDE.md, so the check has to read it; otherwise its
#         own advice is unfollowable and the hygiene score stays capped at 95.
mkdir -p "$TMP/projE"
( cd "$TMP/projE" && git init -q -b master && \
  git remote add origin git@github.com:fake/projE.git && \
  printf '# Project\n\nRun `/ai:review` before a release, not after it.\n' > CLAUDE.md && \
  git add CLAUDE.md && \
  for i in 1 2 3 4 5 6 7; do
    git -c user.email=a@x -c user.name=A commit -q --allow-empty -m "c$i"
  done )
OUT_E="$(PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projE" 2>&1 || true)"
assert "single committer + documented cadence: drift does NOT fire" \
  '! echo "$OUT_E" | grep -qiE "no reviewer cadence documented"'
assert "single committer + documented cadence: reports the cadence as found" \
  'echo "$OUT_E" | grep -qiE "reviewer cadence documented"'

# --- 5. None of the drift checks should make doctor exit 2 (error) ---
set +e
PATH="$TMP/stub-bin:$PATH" bash "$DOCTOR" "$TMP/projB" >/dev/null 2>&1
EXIT_B=$?
set -e
assert "drift checks never raise to error (exit 2)" '[ "$EXIT_B" -ne 2 ]'

print_summary_and_exit
