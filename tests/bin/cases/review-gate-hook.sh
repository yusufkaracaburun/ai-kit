#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/review-gate.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
git config --global user.email t@t
git config --global user.name t
git config --global init.defaultBranch main

fire() {
  # fire <cwd> <command> -> deny reason, empty if silent
  jq -n --arg c "$2" --arg d "$1" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true
}

R="$TMP/repo"
mkdir -p "$R"
git -C "$R" init -q
echo '{"branches": {}}' >"$R/.ai-kit-setup"
echo a >"$R/a.txt"
git -C "$R" add .
git -C "$R" commit -qm init
echo b >"$R/b.txt"
git -C "$R" add b.txt

echo "=== review-gate: commit ==="
# section: review-gate-commit
OUT=$(fire "$R" "git commit -m x")
assert "commit without a marker is denied" '[ -n "$OUT" ]'
assert "reason names /ai:review and the staged tree" \
  'grep -q "/ai:review" <<<"$OUT" && grep -q "$(git -C "$R" write-tree | cut -c1-7)" <<<"$OUT"'
OUT=$(fire "$R" "git status && git log -m")
assert "other git commands are silent" '[ -z "$OUT" ]'
OUT=$(fire "$R" "echo 'git commit -m x'")
assert "quoted git commit is silent" '[ -z "$OUT" ]'
bash "$HOOK" --approve "$R" >/dev/null
assert "approve writes the staged tree to the marker" \
  '[ "$(head -1 "$R/.git/ai-kit/review-ok")" = "$(git -C "$R" write-tree)" ]'
OUT=$(fire "$R" "git commit -m x")
assert "commit of the approved tree is silent" '[ -z "$OUT" ]'
OUT=$(fire "$R" "git -c core.editor=true --no-pager commit -m 'a; b'")
assert "commit with global options of the approved tree is silent" '[ -z "$OUT" ]'
echo c >"$R/c.txt"
git -C "$R" add c.txt
OUT=$(fire "$R" "git commit -m x")
assert "an extra git add makes the approval stale" '[ -n "$OUT" ]'
OUT=$(fire "$R" "git -c a.b=c --no-pager commit -m x")
assert "commit with global options of a stale tree is denied" '[ -n "$OUT" ]'
assert "deny names the user-only skip override" 'grep -q -- "--skip" <<<"$OUT"'

echo "=== review-gate: skip ==="
# section: review-gate-skip
bash "$HOOK" --approve --skip "hotfix, reviewer down" "$R" >/dev/null
OUT=$(fire "$R" "git commit -m x")
assert "commit after --approve --skip is silent" '[ -z "$OUT" ]'
assert "skip appends date, tree and reason to gate-log" \
  'grep -qE "^[0-9T:Z-]+ $(git -C "$R" write-tree) hotfix, reviewer down$" "$R/.git/ai-kit/gate-log"'
assert "skip reason lands on marker line 2" 'sed -n 2p "$R/.git/ai-kit/review-ok" | grep -q "hotfix, reviewer down"'

echo "=== review-gate: commit outside the index ==="
# section: review-gate-commit-all
for c in "git commit -am x" "git commit --all -m x" "git commit -m x a.txt" "git commit -i -m x a.txt" \
  "git commit --only -m x" "git commit -m x -- a.txt" "git commit -sam x"; do
  OUT=$(fire "$R" "$c")
  assert "approved tree, still denied: $c" 'grep -q "stage explicitly, then /ai:review" <<<"$OUT"'
done
HEREDOC_CMD="git commit -m \"\$(cat <<'EOF'
fix: a; b && git push

Body, with a.txt and -a.
EOF
)\""
for c in "git commit -sm x" "git commit -F msg.txt" "git commit -C HEAD" "git commit --amend --no-edit" \
  "git commit --author=x -m y" "git commit -mfoo" "$HEREDOC_CMD"; do
  OUT=$(fire "$R" "$c")
  assert "approved tree, silent: ${c%%$'\n'*}" '[ -z "$OUT" ]'
done
OUT=$(fire "$R" "git commit -m x 2>&1 | tail -3")
assert "redirects after the commit are not pathspecs" '[ -z "$OUT" ]'

echo "=== review-gate: push ==="
# section: review-gate-push
git -C "$R" commit -qm gated
OUT=$(fire "$R" "git push -u origin main")
assert "push after a gated commit is silent" '[ -z "$OUT" ]'
echo d >"$R/d.txt"
git -C "$R" add d.txt
OUT=$(fire "$R" "git push")
assert "push checks HEAD, not unreviewed staged work" '[ -z "$OUT" ]'
git -C "$R" commit -qm ungated
OUT=$(fire "$R" "git push")
assert "push of an unreviewed HEAD tree is denied" '[ -n "$OUT" ] && grep -q "/ai:review" <<<"$OUT"'
for c in "git push origin -d feat" "git push --delete origin feat"; do
  OUT=$(fire "$R" "$c")
  assert "branch delete is silent: $c" '[ -z "$OUT" ]'
done

echo "=== review-gate: worktrees ==="
# section: review-gate-worktree
W="$TMP/wt"
git -C "$R" worktree add -q "$W" -b wt
echo w >"$W/w.txt"
git -C "$W" add w.txt
bash "$HOOK" --approve "$W" >/dev/null
OUT=$(fire "$W" "git commit -m x")
assert "worktree approval unlocks that worktree" '[ -z "$OUT" ]'
OUT=$(fire "$R" "git -C $W commit -m x")
assert "git -C <worktree> commit reads the worktree marker" '[ -z "$OUT" ]'
OUT=$(fire "$TMP" "git -C wt commit -m x")
assert "relative -C resolves against cwd" '[ -z "$OUT" ]'
OUT=$(fire "$TMP" "git -C repo commit -m x")
assert "relative -C to the main repo is denied" '[ -n "$OUT" ]'
OUT=$(fire "$R" "cd $W && git commit -m x")
assert "leading cd <worktree> && commit reads the worktree marker" '[ -z "$OUT" ]'
OUT=$(fire "$R" "git commit -m x")
assert "main repo stays denied after a worktree approval" '[ -n "$OUT" ]'
OUT=$(fire "$W" "git -C $R commit -m x")
assert "git -C <main> from the worktree is denied" '[ -n "$OUT" ]'

echo "=== review-gate: forms the hook cannot vouch for ==="
# section: review-gate-hardening
H="$TMP/hard"
O="$TMP/other"
P="$TMP/plain"
mkdir -p "$P"
for x in "$H" "$O"; do
  git init -q "$x"
  echo '{"branches": {}}' >"$x/.ai-kit-setup"
  echo a >"$x/a"
  git -C "$x" add .
  git -C "$x" commit -qm i
done
echo b >"$H/b"
git -C "$H" add b
plain="use an unquoted absolute path"
OUT=$(CLAUDE_PROJECT_DIR="$H" fire "$P" 'git -C "$WT" commit -m x')
assert "unsure target outside a repo cwd is judged by CLAUDE_PROJECT_DIR" 'grep -q "$plain" <<<"$OUT"'
OUT=$(fire "$P" 'git -C "$WT" commit -m x')
assert "unsure target with no gated project is silent" '[ -z "$OUT" ]'
for cwd in "$P" "$O"; do
  for c in "git -C \"$H\" commit -m x" "git -C '$H' commit -m x" "cd '$H' && git commit -m x" \
    "cd \"$H\" && git commit -m x" "(cd $H && git commit -m x)" "pushd $H && git commit -m x"; do
    OUT=$(fire "$cwd" "$c")
    assert "unapproved, denied from ${cwd##*/}: $c" '[ -n "$OUT" ]'
  done
done
for c in 'git -C "$WT" commit -m x' 'cd $WT && git commit -m x' 'git -C `pwd` commit -m x' \
  "git -C ~nobody commit -m x" "git -C $TMP/missing commit -m x" "cd $P && git -C REPO commit -m x" \
  "GIT_DIR=.git git commit -m x" "git --git-dir=.git commit -m x" "git --work-tree . commit -m x" \
  'git -C "" commit -m x'; do
  OUT=$(fire "$O" "$c")
  assert "unsure target, denied with the plain form: $c" 'grep -q "$plain" <<<"$OUT"'
done
for c in "bash -c \"git commit -m x\"" "sh -c 'git commit -m x'" "zsh -lc 'cd x; git push'"; do
  OUT=$(fire "$H" "$c")
  assert "shell wrapper denied: $c" 'grep -q "run git directly, not through a shell wrapper" <<<"$OUT"'
done
OUT=$(CLAUDE_PROJECT_DIR="$P" fire "$H" "bash -c 'git commit -m x'")
assert "wrapper denied when cwd is gated but CLAUDE_PROJECT_DIR is not" 'grep -q "shell wrapper" <<<"$OUT"'
OUT=$(fire "$H" "bash -c 'echo hi'")
assert "shell wrapper without git commit is silent" '[ -z "$OUT" ]'
for c in "(git commit -m x)" "{ git commit -m x; }" "env git commit -m x" "command git commit -m x" \
  "time git commit -m x" "! git commit -m x" "if true; then git commit -m x; fi" "eval git commit -m x" \
  'echo $(git commit -m x)' "git -P commit -m x" "git -p commit -m x" "git  commit -m x" \
  "/usr/bin/git commit -m x" "sudo git commit -m x" "nice git commit -m x" "git commit -m x &" \
  "xargs git commit -m x"; do
  OUT=$(fire "$H" "$c")
  assert "unapproved, wrapped form denied: $c" '[ -n "$OUT" ]'
done

bash "$HOOK" --approve "$H" >/dev/null
echo c >"$H/c"
for c in "git add c && git commit -m x" "git rm a; git commit -m x" "git stash && git commit -m x" \
  "git -C $H add c && git -C $H commit -m x"; do
  OUT=$(fire "$H" "$c")
  assert "staging in the same command denied: $c" 'grep -q "stage in a separate command, then /ai:review" <<<"$OUT"'
done
for c in "git -C \"$H\" commit -m x" "cd '$H' && git commit -m x"; do
  OUT=$(fire "$O" "$c")
  assert "approved, quoted plain path from another repo is silent: $c" '[ -z "$OUT" ]'
done
for c in "git commit -m x && git push" "git commit -m x && git push -u origin HEAD"; do
  OUT=$(fire "$H" "$c")
  assert "approved, commit then push in one command is silent: $c" '[ -z "$OUT" ]'
done
for c in "git pull --rebase && git push" "git rebase main; git push" "git merge x && git push"; do
  OUT=$(fire "$H" "$c")
  assert "push after a HEAD move in the same command denied: $c" 'grep -q "rebase, pull or merge" <<<"$OUT"'
done
CC_HEREDOC="git commit -m \"\$(cat <<'EOF'
fix(x): quote \"y\" and a | b; c && d

git commit -a -m nope
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)\""
OUT=$(fire "$H" "$CC_HEREDOC")
assert "Claude Code heredoc commit of the approved tree is silent" '[ -z "$OUT" ]'
OUT=$(fire "$H" "${CC_HEREDOC/git commit -a -m nope/run bash -c \"git push\" later}")
assert "heredoc body naming a shell wrapper is silent" '[ -z "$OUT" ]'
for c in "git switch -c feat/x && git commit -m x" "git checkout -b feat/x && git commit -m x"; do
  OUT=$(fire "$H" "$c")
  assert "new branch keeps the index, approved commit silent: $c" '[ -z "$OUT" ]'
done
OUT=$(fire "$H" "git checkout -b feat/x origin/main && git commit -m x")
assert "new branch from another start point is denied" '[ -n "$OUT" ]'
OUT=$(fire "$H" "git add c && $CC_HEREDOC")
assert "heredoc commit after git add in the same command is denied" '[ -n "$OUT" ]'
for c in 'git commit -m "a \" b" -a' "git commit --message=x --all" "git commit -m 'it'\"'\"'s' -a"; do
  OUT=$(fire "$H" "$c")
  assert "approved tree, still denied: $c" 'grep -q "stage explicitly, then /ai:review" <<<"$OUT"'
done

echo "=== review-gate: marker gate and failure safety ==="
# section: review-gate-safety
N="$TMP/nomarker"
git init -q "$N"
echo n >"$N/n.txt"
git -C "$N" add n.txt
OUT=$(fire "$N" "git commit -m x")
assert "repo without .ai-kit-setup is silent" '[ -z "$OUT" ]'
echo '{"branches": {"review_gate_hook": "skipped"}}' >"$N/.ai-kit-setup"
OUT=$(fire "$N" "git commit -m x")
assert "review_gate_hook skipped is silent" '[ -z "$OUT" ]'
echo '{"branches": {"review_gate_hook": "wired"}}' >"$N/.ai-kit-setup"
OUT=$(fire "$N/" "git commit -m x")
assert "review_gate_hook wired fires" '[ -n "$OUT" ]'
bash "$AIKIT/bin/write-setup-marker.sh" "$N" --review-gate-hook=skipped >/dev/null 2>&1 || true
assert "write-setup-marker records --review-gate-hook" \
  '[ "$(jq -r .branches.review_gate_hook "$N/.ai-kit-setup")" = skipped ]'
mkdir -p "$TMP/plain"
OUT=$(fire "$TMP/plain" "git commit -m x")
assert "outside a repo is silent" '[ -z "$OUT" ]'
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1)
EMPTY_RC=$?
JUNK_OUT=$(echo 'not json' | bash "$HOOK" 2>&1)
JUNK_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
assert "malformed payload exits 0 silent" '[ "$JUNK_RC" -eq 0 ] && [ -z "$JUNK_OUT" ]'

echo "=== review-gate: lead-guard lets the lead approve ==="
# section: review-gate-lead
export HOME="$TMP/home"
bash "$AIKIT/bin/ai-kit-claim.sh" --session lead1 set role=lead >/dev/null
lead() {
  jq -n --arg t "$1" --argjson i "$2" '{session_id: "lead1", tool_name: $t, tool_input: $i}' |
    bash "$AIKIT/bin/hooks/lead-guard.sh" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true
}
OUT=$(lead Bash '{"command": "bash \"${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/hooks/review-gate.sh\" --approve"}')
assert "lead may run review-gate.sh --approve" '[ -z "$OUT" ]'
OUT=$(lead Bash '{"command": "echo x > .git/ai-kit/review-ok"}')
assert "lead may not write the marker by redirect" '[ -n "$OUT" ]'
OUT=$(lead Write '{"file_path": "/repo/.git/ai-kit/review-ok"}')
assert "lead may not Write under .git/" '[ -n "$OUT" ]'

echo "=== review-gate: plugin delivery ==="
# section: review-gate-plugin
assert "hooks.json registers review-gate once, on PreToolUse matcher Bash" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
hits = [(ev, b[\"matcher\"]) for ev, bs in d[\"hooks\"].items() for b in bs for h in b[\"hooks\"]
        if h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/hooks/review-gate.sh\"]
assert hits == [(\"PreToolUse\", \"Bash\")], hits
"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'
assert "plugin copy is the bin/hooks script" 'cmp -s "$HOOK" "$AIKIT/workflow/hooks/review-gate.sh"'

print_summary_and_exit
