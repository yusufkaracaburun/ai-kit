#!/usr/bin/env bash
# Integration test for /ai:docs-sync — finished-work section (#94).
#
# Covers (per #94 acceptance criteria):
#   - section appears after repo-hygiene
#   - merged-branch detection (excludes default + currently-checked-out)
#   - strict closes/fixes/resolves regex (no fuzzy "addresses #N" / "see #N")
#   - local-branch-delete is group-confirmable
#   - remote-branch-delete is INDIVIDUAL per item (no batch flag exists)
#   - gh issue close is INDIVIDUAL per item (no batch flag exists)
#   - non-git repo → section skips cleanly
#   - --skip-finished-work flag bypasses the section
#   - gh not authenticated → closable-issues sub-check skips with warning
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

DRIVER="$AIKIT/bin/ai-kit-docs-sync.sh"
FINISHED="$AIKIT/bin/ai-kit-docs-sync-finished-work.sh"

echo "=== artefacts-exist ==="
assert "finished-work script exists + executable" '[ -x "$FINISHED" ]'

echo "=== no-flags-no-batch-allowed ==="
# Belt-and-braces: scan the helper script source for unintended batch flags.
assert "no --yes-all flag in source" \
  '! grep -F -q "\-\-yes-all" "$FINISHED"'
assert "no --batch flag in source" \
  '! grep -F -q "\-\-batch" "$FINISHED"'
assert "remote delete prompts per branch (loops over MERGED_BRANCHES inside ask block)" \
  'awk "/Also delete REMOTE branch/" "$FINISHED" | grep -q "origin/\$b"'
assert "issue close prompts per issue (loops over CLOSABLE_ISSUES inside ask block)" \
  'awk "/Close issue #/" "$FINISHED" | grep -q "\\\$issue_num"'

echo "=== non-git-skip ==="
TMP_NOGIT=$(mktemp -d)
TMP_GIT=""
TMP_ACCEPT=""
TMP_REGEX=""
TMP_SKIP=""
cleanup() {
  for d in "$TMP_NOGIT" "$TMP_GIT" "$TMP_ACCEPT" "$TMP_REGEX" "$TMP_SKIP"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT
OUTPUT_NOGIT="$(bash "$DRIVER" "$TMP_NOGIT" --skip-dead-links --skip-repo-hygiene --no-prompt 2>&1 || true)"
RC_NOGIT=$(bash "$DRIVER" "$TMP_NOGIT" --skip-dead-links --skip-repo-hygiene --no-prompt >/dev/null 2>&1; echo $?)
assert "non-git repo exits 0 from finished-work" '[ "$RC_NOGIT" = "0" ]'
assert "non-git output mentions 'not a git repo — skipped'" \
  'echo "$OUTPUT_NOGIT" | grep -q "not a git repo"'

echo "=== git-with-merged-branches ==="
TMP_GIT=$(mktemp -d)
(
  cd "$TMP_GIT"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "init" > R.md
  git add R.md
  git commit -q -m "init"
  for n in 1 2; do
    git checkout -q -b "feature/merged-$n"
    echo "f" > "f$n.txt"
    git add "f$n.txt"
    git commit -q -m "f$n"
    git checkout -q master
    git merge -q --no-ff "feature/merged-$n" -m "merge $n"
  done
  git checkout -q -b "feature/unmerged"
  echo "u" > u.txt
  git add u.txt
  git commit -q -m "u"
  git checkout -q master
) >/dev/null 2>&1
OUTPUT_GIT="$(bash "$DRIVER" "$TMP_GIT" --skip-dead-links --skip-repo-hygiene --no-prompt 2>&1 || true)"
RC_GIT=$(bash "$DRIVER" "$TMP_GIT" --skip-dead-links --skip-repo-hygiene --no-prompt >/dev/null 2>&1; echo $?)
assert "git repo with merged branches exits 1" '[ "$RC_GIT" = "1" ]'
assert "default branch detected as master" \
  'echo "$OUTPUT_GIT" | grep -q "default branch: master"'
assert "feature/merged-1 reported" \
  'echo "$OUTPUT_GIT" | grep -q "feature/merged-1"'
assert "feature/merged-2 reported" \
  'echo "$OUTPUT_GIT" | grep -q "feature/merged-2"'
assert "feature/unmerged NOT reported" \
  '! echo "$OUTPUT_GIT" | grep -q "feature/unmerged"'
assert "default (master) NOT reported in merged list" \
  '! echo "$OUTPUT_GIT" | grep -qE "^    master"'

echo "=== current-branch-excluded ==="
# Already on feature/merged-1? Check master first then switch.
git -C "$TMP_GIT" checkout feature/merged-1 >/dev/null 2>&1 || true
OUT_CUR="$(bash "$DRIVER" "$TMP_GIT" --skip-dead-links --skip-repo-hygiene --no-prompt 2>&1 || true)"
assert "currently checked-out merged branch is excluded from list" \
  '! echo "$OUT_CUR" | grep -qE "^    feature/merged-1"'
git -C "$TMP_GIT" checkout master >/dev/null 2>&1 || true

echo "=== accept-deletes-local-only ==="
TMP_ACCEPT=$(mktemp -d)
(
  cd "$TMP_ACCEPT"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "init" > R.md
  git add R.md
  git commit -q -m "init"
  git checkout -q -b "feature/delete-me"
  echo "d" > d.txt
  git add d.txt
  git commit -q -m "d"
  git checkout -q master
  git merge -q --no-ff "feature/delete-me" -m "merge"
) >/dev/null 2>&1
# AUTO_YES is test-only; remote delete + gh close are skipped because there's no remote.
AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1 bash "$FINISHED" "$TMP_ACCEPT" >/dev/null 2>&1 || true
BRANCHES_AFTER="$(git -C "$TMP_ACCEPT" branch --format='%(refname:short)')"
assert "feature/delete-me deleted on AUTO_YES accept" \
  '! echo "$BRANCHES_AFTER" | grep -qx "feature/delete-me"'
assert "master kept" \
  'echo "$BRANCHES_AFTER" | grep -qx "master"'

echo "=== regex-strictness ==="
TMP_REGEX=$(mktemp -d)
# Test the strict closes/fixes/resolves regex in isolation against synthetic
# PR bodies — no GH calls needed.
PYTEST="$(cat <<'PY'
import re
pat = re.compile(r"(?<![A-Za-z])(?:closes|fixes|resolves)\s+#(\d+)", re.IGNORECASE)
cases = [
    ("closes #42",      ["42"]),
    ("Fixes #7",        ["7"]),
    ("RESOLVES #999",   ["999"]),
    ("closes #1, fixes #2", ["1", "2"]),
    ("addresses #5",    []),
    ("see #5",          []),
    ("for #5",          []),
    ("preclosesnp #1",  []),
    ("closesss #1",     []),
]
for body, want in cases:
    got = pat.findall(body)
    assert got == want, f"FAIL: {body!r} → {got!r} != {want!r}"
print("regex-ok")
PY
)"
assert "strict closes/fixes/resolves regex passes" \
  '[ "$(python3 -c "$PYTEST")" = "regex-ok" ]'

echo "=== skip-flag ==="
TMP_SKIP=$(mktemp -d)
(
  cd "$TMP_SKIP"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x; git add x; git commit -q -m "x"
  git checkout -q -b "feature/will-be-merged"
  echo "y" > y; git add y; git commit -q -m "y"
  git checkout -q master
  git merge -q --no-ff "feature/will-be-merged" -m "m"
) >/dev/null 2>&1
RC_SKIP=$(bash "$DRIVER" "$TMP_SKIP" --skip-dead-links --skip-repo-hygiene --skip-finished-work --no-prompt >/dev/null 2>&1; echo $?)
assert "--skip-finished-work bypasses section (exit 0)" '[ "$RC_SKIP" = "0" ]'

echo "=== gh-auth-hostname ==="
# Plain auth status fails, as it does with a second GitHub host in hosts.yml.
TMP_GHAUTH=$(mktemp -d)
mkdir -p "$TMP_GHAUTH/stub-bin" "$TMP_GHAUTH/repo"
(
  cd "$TMP_GHAUTH/repo"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x; git add x; git commit -q -m "x"
) >/dev/null 2>&1
cat > "$TMP_GHAUTH/stub-bin/gh" <<'STUB'
#!/usr/bin/env bash
# Real gh wants -R OWNER/REPO; a filesystem path must fail.
prev=""
for a in "$@"; do
  if [ "$prev" = "-R" ] || [ "$prev" = "--repo" ]; then
    case "$a" in /*|.*|"~"*) exit 1 ;; esac
  fi
  prev="$a"
done
case "$*" in
  *"auth status --hostname github.com"*) exit 0 ;;
  *"auth status"*) exit 1 ;;
  *"pr list"*) echo '[{"number":9,"body":"closes #5","url":"https://example.test/pr/9"}]' ;;
  *"issue view 5"*"state"*) echo OPEN ;;
  *"issue view 5"*"title"*) echo "stub issue" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$TMP_GHAUTH/stub-bin/gh"
OUT_GHAUTH="$(PATH="$TMP_GHAUTH/stub-bin:$PATH" bash "$FINISHED" "$TMP_GHAUTH/repo" --no-prompt 2>&1 || true)"
assert "gh auth pinned to github.com: closable issue listed" 'echo "$OUT_GHAUTH" | grep -qF "#5"'
rm -rf "$TMP_GHAUTH"

echo "=== squash-merged-branches ==="
# A squash merge leaves the branch outside `git branch --merged`; gh knows its PR merged.
TMP_SQ=$(mktemp -d)
mkdir -p "$TMP_SQ/stub-bin" "$TMP_SQ/repo"
(
  cd "$TMP_SQ/repo"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x; git add x; git commit -q -m "x"
  for b in feature/squashed feature/squashed-ahead feature/tagged feature/open; do
    git checkout -q -b "$b" master
    echo "$b" > "${b#feature/}.txt"; git add .; git commit -q -m "$b"
    git checkout -q master
  done
  git merge -q --squash feature/squashed; git commit -q -m "squash"
  git merge -q --squash feature/squashed-ahead; git commit -q -m "squash ahead"
  git merge -q --squash feature/tagged; git commit -q -m "squash tagged"
  git checkout -q -b feature/plain
  echo "p" > p.txt; git add p.txt; git commit -q -m "p"
  git checkout -q master
  git merge -q --no-ff feature/plain -m "merge plain"
  git checkout -q -b release/1.0
  git checkout -q -b epic/x
  git checkout -q master
) >/dev/null 2>&1
SQ_OID="$(git -C "$TMP_SQ/repo" rev-parse feature/squashed)"
AHEAD_OID="$(git -C "$TMP_SQ/repo" rev-parse feature/squashed-ahead)"
TAG_OID="$(git -C "$TMP_SQ/repo" rev-parse feature/tagged)"
git -C "$TMP_SQ/repo" checkout -q feature/squashed-ahead
echo "later" > "$TMP_SQ/repo/later.txt"
git -C "$TMP_SQ/repo" add later.txt
git -C "$TMP_SQ/repo" -c user.email=t@example.com -c user.name=T commit -q -m "after merge"
git -C "$TMP_SQ/repo" checkout -q feature/tagged
git -C "$TMP_SQ/repo" -c user.email=t@example.com -c user.name=T commit -q --allow-empty -m "after merge"
git -C "$TMP_SQ/repo" tag feature/tagged "$TAG_OID"
git -C "$TMP_SQ/repo" checkout -q master
cat > "$TMP_SQ/stub-bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"auth status"*) exit 0 ;;
  *"--head feature/squashed-ahead"*) echo "$AHEAD_OID" ;;
  *"--head feature/squashed"*) echo "$SQ_OID" ;;
  *"--head feature/tagged"*) echo "$TAG_OID" ;;
  *"--head release/1.0"*) echo "$SQ_OID" ;;
  *"--head epic/x"*) echo "$SQ_OID" ;;
  *"--head"*) : ;;
  *"pr list"*) echo '[]' ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$TMP_SQ/stub-bin/gh"
OUT_SQ="$(PATH="$TMP_SQ/stub-bin:$PATH" bash "$FINISHED" "$TMP_SQ/repo" --no-prompt 2>&1 || true)"
assert "squash-merged branch listed with git branch -D" \
  'echo "$OUT_SQ" | grep -E "^    feature/squashed " | grep -qF "git branch -D"'
assert "plain-merged branch listed with git branch -d" \
  'echo "$OUT_SQ" | grep -E "^    feature/plain " | grep -qF "git branch -d"'
assert "branch with commits after its merged PR NOT listed" \
  '! echo "$OUT_SQ" | grep -qE "^    feature/squashed-ahead "'
assert "branch without merged PR NOT listed" \
  '! echo "$OUT_SQ" | grep -qE "^    feature/open "'
assert "release/* NOT listed" \
  '! echo "$OUT_SQ" | grep -qE "^    release/"'
assert "epic/* NOT listed" \
  '! echo "$OUT_SQ" | grep -qE "^    epic/"'
assert "branch ahead of merged PR NOT listed when a same-named tag points at the PR head" \
  '! echo "$OUT_SQ" | grep -qE "^    feature/tagged "'
PATH="$TMP_SQ/stub-bin:$PATH" AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1 bash "$FINISHED" "$TMP_SQ/repo" >/dev/null 2>&1 || true
SQ_AFTER="$(git -C "$TMP_SQ/repo" branch --format='%(refname:short)')"
assert "squash-merged branch deleted on accept" '! echo "$SQ_AFTER" | grep -qx "feature/squashed"'
assert "plain-merged branch deleted on accept" '! echo "$SQ_AFTER" | grep -qx "feature/plain"'
assert "open branch kept on accept" 'echo "$SQ_AFTER" | grep -qx "feature/open"'

echo "=== squash-merged-no-gh ==="
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP_SQ/stub-bin/gh"
git -C "$TMP_SQ/repo" branch -q -f feature/squashed "$SQ_OID"
git -C "$TMP_SQ/repo" branch -q feature/plain-again master
OUT_NOGH="$(PATH="$TMP_SQ/stub-bin:$PATH" bash "$FINISHED" "$TMP_SQ/repo" --no-prompt 2>&1 || true)"
assert "gh unauthenticated: squash-merged branch NOT listed" \
  '! echo "$OUT_NOGH" | grep -qE "^    feature/squashed "'
assert "gh unauthenticated: warn line still printed" \
  'echo "$OUT_NOGH" | grep -qF "gh not available or not authenticated"'

echo "=== delete-error-surfaced ==="
# With HEAD on a branch that lacks the merged one, `git branch -d` refuses it.
(
  cd "$TMP_SQ/repo"
  git checkout -q -b feature/plain2 master
  echo "q" > q.txt; git add q.txt; git commit -q -m "q"
  git checkout -q master
  git merge -q --no-ff feature/plain2 -m "merge plain2"
  git checkout -q -b elsewhere master~3
) >/dev/null 2>&1
OUT_DELERR="$(PATH="$TMP_SQ/stub-bin:$PATH" AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1 bash "$FINISHED" "$TMP_SQ/repo" 2>&1 || true)"
assert "failed delete shows git's error" \
  'echo "$OUT_DELERR" | grep -F "feature/plain2" | grep -qi "not fully merged"'
rm -rf "$TMP_SQ"

print_summary_and_exit
