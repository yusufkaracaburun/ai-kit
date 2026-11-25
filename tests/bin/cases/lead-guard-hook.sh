#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/lead-guard.sh"

# Claims are written by the real claim script, so a change to its frontmatter
# format breaks this test instead of silently disarming the guard.
TMP_H=$(mktemp -d)
export HOME="$TMP_H"
bash "$AIKIT/bin/ai-kit-claim.sh" --session lead1 set role=lead >/dev/null
bash "$AIKIT/bin/ai-kit-claim.sh" --session build1 set role=build >/dev/null

fire() {
  # fire <session_id> <tool_name> <tool_input-json> [agent_id] -> deny reason, empty if silent
  local agent=""
  [ -n "${4:-}" ] && agent=",\"agent_id\":\"$4\""
  bash "$HOOK" <<<"{\"session_id\":\"$1\",\"tool_name\":\"$2\",\"tool_input\":$3$agent}" |
    jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true
}
bash_cmd() { fire lead1 Bash "{\"command\":\"$1\"}"; }
fire_agent_json() {
  # fire_agent_json <agent_id json literal>: lead Edit with that raw agent_id value
  bash "$HOOK" <<<"{\"session_id\":\"lead1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/repo/src/a.ts\"},\"agent_id\":$1}" |
    grep -o '"deny"' || true
}
export TMPDIR="$TMP_H/tmpdir/"

echo "=== lead-guard: file edits ==="
# section: lead-guard-edits
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/a.ts"}')
assert "lead Edit on a repo file is denied" '[ -n "$OUT" ]'
assert "reason names lead-guard and the tool" 'grep -q "lead-guard" <<<"$OUT" && grep -q "Edit" <<<"$OUT"'
OUT=$(fire build1 Edit '{"file_path":"/repo/src/a.ts"}')
assert "role=build is silent" '[ -z "$OUT" ]'
OUT=$(fire noclaim Edit '{"file_path":"/repo/src/a.ts"}')
assert "no claim file is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write "{\"file_path\":\"$HOME/.claude/projects/p/memory/note.md\"}")
assert "Write under \$HOME/.claude is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/tmp/x"}')
assert "Write to /tmp is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/private/tmp/x"}')
assert "Write to /private/tmp is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write "{\"file_path\":\"${TMPDIR}memo.md\"}")
assert "Write under \$TMPDIR is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/repo/.agents/memory/project/note.md"}')
assert "Write under .agents/memory is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/repo/.planning/plan.md"}')
assert "Write under .planning is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/.claude/settings.json"}')
assert "Edit of project .claude/settings.json is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Write '{"file_path":"/repo/.claude/settings.local.json"}')
assert "Write of .claude/settings.local.json is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":".claude/settings.json"}')
assert "Edit of relative .claude/settings.json is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/settings.json"}')
assert "Edit of a settings.json outside .claude is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/.claude/hooks/x.sh"}')
assert "Edit of other files under .claude is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/workflow/bin/foo.sh"}')
assert "Edit of a source script is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/.agents/worktrees/w/src/a.ts"}')
assert "Edit of code in an .agents worktree is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/memory/cache.ts"}')
assert "Edit of src/memory code is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 Edit '{"file_path":"/Users/x/.claude/projects/p/memory/note.md"}')
assert "Edit under another user's .claude is denied" '[ -n "$OUT" ]'
assert "agent_id null counts as main thread" '[ -n "$(fire_agent_json null)" ]'
assert "agent_id empty counts as main thread" '[ -n "$(fire_agent_json "\"\"")" ]'
assert "agent_id set is a subagent" '[ -z "$(fire_agent_json "\"x\"")" ]'
OUT=$(fire lead1 NotebookEdit '{"notebook_path":"/repo/n.ipynb"}')
assert "NotebookEdit on a repo notebook is denied" '[ -n "$OUT" ]'

echo "=== lead-guard: Bash ==="
# section: lead-guard-bash
OUT=$(bash_cmd "git status")
assert "git status is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "git commit -m x")
assert "git commit is denied" '[ -n "$OUT" ] && grep -q "Bash" <<<"$OUT"'
assert "Bash deny points memo writes at the Write tool" 'grep -q "Write tool" <<<"$OUT" && grep -q ".agents/memory" <<<"$OUT"'
OUT=$(fire lead1 Edit '{"file_path":"/repo/src/a.ts"}')
assert "Edit deny carries no Write-tool hint" '[ -n "$OUT" ] && ! grep -q "Write tool" <<<"$OUT"'
OUT=$(bash_cmd "flutter test")
assert "flutter test is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "sed -n 1,5p f")
assert "sed -n is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "sed -i 's/a/b/' f")
assert "sed -i is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "cmd 2>/dev/null")
assert "2>/dev/null is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "cmd 2>&1 | grep x")
assert "2>&1 is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "echo x > f")
assert "redirect to a file is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "asc apps list")
assert "asc list is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "asc apps update --name y")
assert "asc update is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "gh pr view 12")
assert "gh pr view is silent" '[ -z "$OUT" ]'
OUT=$(bash_cmd "gh pr create --fill")
assert "gh pr create is denied" '[ -n "$OUT" ]'
OUT=$(bash_cmd "bash bin/ai-kit-claim.sh show")
assert "ai-kit-claim.sh is silent" '[ -z "$OUT" ]'

allow() { OUT=$(bash_cmd "$1"); assert "allow: $1" '[ -z "$OUT" ]'; }
deny() { OUT=$(bash_cmd "$1"); assert "deny: $1" '[ -n "$OUT" ]'; }
allow "ps -Ao args | grep -E 'pest|paratest|gradle' | grep -v grep"
allow "cat tests/Pest.php"
allow "git log -S kill"
allow "git stash list"
allow "git branch"
allow "git diff --stat"
allow "gh issue list"
allow "gh pr status"
allow "gh api repos/o/r/pulls"
allow "cat > \$TMPDIR/memo.md"
allow "cat > \${TMPDIR}memo.md"
allow "cat >> ${TMPDIR}memo.md"
allow "echo x > /tmp/x"
allow "echo x >> /private/tmp/x"
deny "./vendor/bin/pest"
deny "XDEBUG_MODE=off ./vendor/bin/pest --parallel"
deny "cd app && ./gradlew test"
deny "npx jest"
deny "kill 123"
deny "git stash"
deny "git stash pop"
deny "git clean -fd"
deny "git checkout -- src/a.ts"
deny "git branch -D old"
allow "git branch -d old"
deny "git add src/a.ts"
deny "rm notes.txt"
deny "composer install"
deny "composer update"
deny "composer require foo/bar"
deny "make"
deny "gh api -X POST repos/o/r/issues"
deny "gh api --method PATCH repos/o/r"
deny "gh pr comment 12 --body x"
deny "gh pr review 12 --approve"
allow "gh issue comment 3 --body x"
deny "echo x >> notes.md"
allow "printf 'x' >> ~/.claude/projects/foo/memory/MEMORY.md"
allow "echo w >> $HOME/.claude/projects/foo/memory/MEMORY.md"
allow "echo y >> \\\"\$HOME/.claude/projects/foo/memory/MEMORY.md\\\""
allow "cat > .agents/memory/project/note.md <<'EOF'"
deny "echo z >> src/app.ts"
deny "echo z > README.md"
allow "export PATH=/opt/bin:\$PATH; cd /repo; npx wrangler whoami; npx wrangler deployments list; npx wrangler d1 list; npx wrangler r2 bucket list; npx wrangler kv namespace list; grep -nE 'crons|triggers' wrangler.jsonc"
allow "npx wrangler whoami"
allow "npm ls"
allow "pnpm audit"
allow "yarn outdated"
allow "npx wrangler --version"
deny "cd x && npx wrangler deploy"
deny "npx expo run:ios"
deny "npm test"
deny "npm run build"
deny "pnpm install"
deny "npx wrangler whoami; npx wrangler deploy"
allow "curl -s https://example.com"
allow "curl -I https://example.com"
allow "curl -X GET https://example.com"
deny "curl -X POST https://example.com"
deny "curl --request DELETE https://example.com"
deny "curl -d a=1 https://example.com"
deny "curl --data-raw x https://example.com"
deny "curl -F f=@a https://example.com"
deny "curl -T a https://example.com"
deny "wget --post-data=x https://example.com"
deny "http PUT example.com"
allow "http "
deny "npm run status"
deny "pnpm exec status"
deny "yarn dlx list"
deny "npm create vite"
allow "npx wrangler deployments list"
allow "npm --version"
deny "npx wrangler deploy --version"
deny "npm run build -- --help"
deny "npx wrangler deploy -h"
deny "npm audit --fix"
deny "npm audit fix"
allow "npm doctor"
allow "npm help"
allow "pnpm why"
deny "curl -sd a=1 https://example.com"
deny "curl -da=1 https://example.com"
deny "curl -sF f=@a https://example.com"
deny "curl --json {} https://example.com"
deny "curl --data-urlencode a=1 https://example.com"
deny "http example.com name=x"
deny "https example.com count:=1"
deny "http example.com file@a.txt"
allow "http example.com Accept:application/json"
allow "curl -fsSL https://example.com"
allow "curl -D - https://example.com"
allow "curl -o f https://example.com"
deny "perl -pi -e 's/a/b/' f"
deny "perl -i.bak -pe 's/a/b/' f"
allow "perl -ne 'print if /x/' f"
allow "perl -Ilib -e 'print 1'"
deny "python3 -c 'open(\\\"f\\\", \\\"w\\\").write(\\\"x\\\")'"
deny "python -c 'import os; os.remove(\\\"f\\\")'"
deny "node -e 'require(\\\"fs\\\").writeFileSync(\\\"f\\\", \\\"x\\\")'"
allow "python3 -c 'print(1)'"
allow "python3 -c 'import json,sys; print(json.load(sys.stdin)[\\\"a\\\"])' < f.json"
allow "node -e 'console.log(process.version)'"
allow "python3 -c 'print(1)' | grep remove"
allow "python3 -c 'import sqlite3; c = sqlite3.connect(\\\"db\\\"); print(c.execute(\\\"SELECT 1\\\").fetchall())'"
deny "node -e \\\"fs.rmSync('x')\\\""
allow "python3 --version"
deny "touch f"
deny "mkdir -p d"
deny "ln -s a b"
allow "ls -ln"
deny "git switch main"
deny "git tag v1.0"
deny "git tag -a v1.0 -m x"
deny "git tag -d v1.0"
allow "git tag"
allow "git tag -l"
allow "git tag --list 'v*'"
allow "git tag --contains HEAD"
deny "git revert HEAD"
deny "git apply p.diff"
allow "git apply --check p.diff"
allow "git apply --stat p.diff"
deny "git am p.patch"
deny "git -C /x commit -m a"
deny "git -c user.name=a commit"
deny "git -C a -C b push"
deny "cd r && git -C x add f"
allow "git -C x status"
allow "git -C x log"
allow "git -c core.pager=cat diff"
deny "/usr/bin/git -C x commit"
deny "git --no-pager commit"
deny "git -P commit"
deny "git -C x --no-pager push"
allow "git --no-pager log"
allow "git -P diff"
deny "command rm -f x"
deny "command git commit"
allow "command -v git"
deny "wrangler deploy"
allow "wrangler whoami"
allow "wrangler --version"
deny "gplay upload --track internal"
allow "gplay tracks list"
deny "pytest"
deny "python3 -m pytest"
deny "cargo build"
deny "cargo test"
deny "cargo run"
allow "cargo --version"
deny "cargo publish"
deny "cargo install ripgrep"
deny "go test ./..."
allow "go version"
# the review skill's main thread runs this under role=lead, so lead-guard must not block it
allow "bash bin/review-gate.sh --approve"

echo "=== lead-guard: coordination rights ==="
# section: lead-guard-coordination
REPO="$TMP_H/repo" OUTSIDE="$TMP_H/outside" SCRATCH="$TMP_H/tmpdir/s"
mkdir -p "$REPO/docs/sub" "$REPO/.agents/memory" "$OUTSIDE" "$SCRATCH/d"
git -C "$REPO" init -q
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$REPO" worktree add -q "$TMP_H/wt" 2>/dev/null
git -C "$OUTSIDE" init -q
ln -s "$REPO" "$SCRATCH/link"
touch "$REPO/a.md" "$REPO/docs/b.md" "$SCRATCH/f"
raw() {
  # raw <command>: the command verbatim, cwd in the repo
  jq -n --arg c "$1" --arg d "$REPO" '{session_id: "lead1", tool_name: "Bash", cwd: $d, tool_input: {command: $c}}' |
    bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty'
}
ok() { OUT=$(raw "$1"); assert "allow: ${1:0:100}" '[ -z "$OUT" ]'; }
no() { OUT=$(raw "$1"); assert "deny: ${1:0:100}" '[ -n "$OUT" ]'; }

# writes through Bash inside the memo and temp dirs
ok "echo x > $SCRATCH/f"
ok 'echo x >>/tmp/f 2>/private/tmp/err'
ok 'echo x >> "$HOME/.claude/n.md"'
ok 'mkdir -p ${TMPDIR}n && cd ${TMPDIR}n && touch a b && rm -f a'
ok "sed -i '' 's/a/b/' /tmp/f"
ok "sed -i.bak -e 's|/x|/y|g' ~/.claude/n.md"
ok "cp $REPO/a.md /tmp/a.md"
ok 'cp -R ../x/*.md /tmp/d/'
ok 'cp /tmp/a "/tmp/b c"'
no 'command rm -f src/a'
ok "/usr/bin/sed -i '' '/^## x/a\\
- y; w src/z
' /tmp/f"
no "sed -i '' '/x/a\\
y
w src/z
' /tmp/f"
ok 'rm -rf /tmp/a/b && rm -f .agents/memory/old.md ~/.claude/n.md .planning/x'
ok 'rm --recursive /tmp/a/b'
for a in -r -R -fr -rf --recursive '-f -R'; do
  no "rm $a ~/.claude/d"
  no "rm $a .agents/memory/d"
  no "rm $a .planning/d"
  no "rm $a /tmp/a .planning/d"
done
for a in 'echo x | tee /tmp/a' 'mv /tmp/a /tmp/b' 'chmod +x /tmp/a' 'ln -s /tmp/a /tmp/b' 'command rm -f /tmp/a' 'S=/tmp/x; rm $S/y' 'S=/tmp/x; echo x > $S/y'; do no "$a"; done
ok "cd $SCRATCH; rm -f old.md; echo x > new.md"
ok "(cd $SCRATCH && rm -f old.md)"
ok 'cat > .agents/memory/n.md'
no 'rm /tmp/../etc/x'
no 'echo x > /tmp/../etc/x'
no 'echo x > /tmp/$UNKNOWN'
no 'echo x > /tmp/$(date +%s)'
no 'cp /tmp/a docs/a.md'
no 'cp /tmp/a "docs/a b.md"'
no 'mv docs/a.md /tmp/a.md'
no 'rm "/tmp/a" "src/b"'
no 'rm /tmp/a src/b'
no 'cp -t src /tmp/a /tmp/b'
no 'tee /tmp/a src/b'
no 'touch /tmp/a src/b'
no 'mkdir -p /tmp/a src/b'
no 'chmod +x src/a.sh'
no 'ln -s /repo/src /tmp/l'
no 'ln -s ../x /tmp/l'
no "sed -i '' 's/a/b/' src/a"
no "sed -i 's/a/b/w src/x' /tmp/a"
no "sed -i '1e git push' /tmp/a"
no "sed -i 's/a/b/e' /tmp/a"
no 'rm -rf /tmp'
no 'rm -rf /tmp/'
no 'rm -rf "$TMPDIR"'
no 'rm -rf /private/tmp/.'
no 'rm -rf /tmp/*'
no 'rm -rf ~/.claude'
no 'rm -rf .planning'
no 'rm -rf .agents/memory/'
no 'rm /tmp/{a,../etc/b}'
no 'rm /tmp/`pwd`'
no 'rm -rf /tmp/$X/y'
no 'S=/tmp/x; read S; rm -rf $S/y'
no 'false && S=/tmp/x; rm -rf $S/y'
for a in "chdir $REPO" "pushd $REPO" "alias x=y" "eval x" "source /tmp/x" ". /tmp/x" "command cd $REPO" "builtin cd $REPO" "HOME=$REPO" "export TMPDIR=$REPO" "read HOME"; do
  no "cd $SCRATCH; $a; rm a"
  no "$a; rm \$HOME/.claude/x"
  no "$a; rm ~/.claude/x"
  no "$a; echo x > \$TMPDIR/x"
done
no 'S=/repo/src; rm -rf $S/y'
no 'false &&
S=/tmp/x; rm -rf $S/y'
no "false && # c
cd $SCRATCH; rm a"
no "cd /tmp && rm -rf *"
no "touch /tmp/a; echo \"it's\"; git push; echo \"it's\""
no "touch /tmp/a; echo it\\'s
git push
echo \\'"
no 'tee /tmp/x >(bash)'
no 'mv /tmp/a/* /tmp/b'
no "git -C $REPO -C /x add a.md"
no 'HOME=/repo; rm ~/.claude/x'
no 'cd src && rm a'
no "false && cd $SCRATCH; rm a"
no "cd $SCRATCH/none; rm a"
no "cd $SCRATCH || rm a"
no "cd $SCRATCH | rm a"
no "(cd $SCRATCH); rm a"
no "cd $SCRATCH && cd - && rm a"
no "cd $SCRATCH && pushd $REPO; rm a"
no "f() { cd $REPO; }; cd $SCRATCH; f; rm a"
no "echo x > $SCRATCH/link/a.md"
no "rm -rf $SCRATCH/link/docs"
no "touch $SCRATCH/d/x && git commit -m x"
no "touch /tmp/a \$'\\'' ; git push ; echo '"
no "# it's
touch /tmp/a; git push; echo 'x'"
no 'echo x > /tmp/a; git push'
no 'cp /tmp/a /tmp/b
git push'
ok "grep -c 'x
rm y' /tmp/a"

# coordination docs at the repo root
doc() { jq -n --arg t "$1" --arg f "$2" --arg d "$REPO" '{session_id: "lead1", tool_name: $t, cwd: $d, tool_input: {file_path: $f}}' | bash "$HOOK"; }
for f in CONTEXT.md docs/decisions.md docs/roadmap.md; do
  for t in Edit Write MultiEdit; do
    OUT=$(doc $t "$REPO/$f")
    assert "$t $f is silent" '[ -z "$OUT" ]'
  done
  OUT=$(doc Edit "$TMP_H/wt/$f")
  assert "Edit $f in a worktree is silent" '[ -z "$OUT" ]'
  OUT=$(doc Edit "$OUTSIDE/$f")
  assert "Edit $f in another repo is denied" '[ -n "$OUT" ]'
done
for f in README.md docs/adr/0001-x.md docs/b.md docs/sub/CONTEXT.md docs/docs/roadmap.md docs/../CONTEXT.md decisions.md; do
  OUT=$(doc Edit "$REPO/$f")
  assert "Edit $f is denied" '[ -n "$OUT" ]'
done
ln -s a.md "$REPO/CONTEXT.md"
OUT=$(doc Edit "$REPO/CONTEXT.md")
assert "Edit of a symlinked CONTEXT.md is denied" '[ -n "$OUT" ]'
no 'echo x >> docs/roadmap.md'

# git add with literal files
ok 'git add a.md docs/b.md'
ok "git -C $REPO add -- a.md"
ok "cd $REPO && git add \"a.md\" 'docs/b.md'"
no 'git add gone.md'
for a in . ./ .. docs docs/ '*.md' "'*.md'" ':/a.md' "':!a.md'" -A -u '-f a.md' '-p a.md' '-i' '-N a.md' '--all' '-- -A' '$F' '"$F"' \
  '$(ls)' '`ls`' '{a,b}.md' '--pathspec-from-file=/tmp/x' '' '--'; do
  no "git add $a"
done
no 'git add ~/a.md'
no 'git -C rel add a.md'
no "git -C $REPO add docs"
no "git -C \$R add a.md"
no 'git add a.md && git commit -m x'
no 'GIT_DIR=/x git add a.md'
no 'cd nowhere; git add a.md'

# clean up without force
ok 'git worktree remove .agents/worktrees/w'
ok 'git branch -d a feat/b'
no 'git worktree remove -f .agents/worktrees/w'
no 'git worktree remove --force .agents/worktrees/w'
no 'git worktree remove .agents/worktrees/w -f'
no 'git worktree remove "$W"'
no 'git branch -D a'
no 'git branch -d -f a'
no 'git branch -df a'
no 'git branch -d a --force'
no 'git branch -M a'
no 'git branch -f a HEAD'
ok 'git branch -m a'
ok 'git branch -vv --merged'
no 'git branch --delete --force a'
no 'git branch -d $(git branch)'
no 'git worktree remove w; git branch -D w'

# issue cards
ok 'gh issue create --title "x; y" --body-file /tmp/b.md'
ok "gh issue edit 3 --add-label 'a (b)'"
ok 'gh issue comment 3 --body "see $X and \`code\`"'
ok 'gh issue comment 3 --body "$(cat /tmp/b.md)"'
ok "gh issue create -t x --body \"\$(cat <<'EOF'
one; git push
EOF
)\""
for a in 'close 3' 'delete 3' 'reopen 3' 'transfer 3 o/r' 'lock 3' 'unlock 3'; do no "gh issue $a"; done
no 'gh issue comment 3 --body "$(git push)"'
no 'gh issue comment 3 --body "`git push`"'
no 'gh issue comment 3 --body $(git push)'
no 'gh issue comment 3 --body x && git push'
no 'gh issue comment 3 --body x > src/a'
no 'gh issue comment 3 --delete-last'
no 'gh issue comment 3 --delete-last=true --yes'
no 'gh issue comment 3 "--delete-last"'
ok 'gh issue comment 3 --edit-last --body x'
no 'gh pr comment 3 --body x'
no 'gh pr merge 3'
no 'gh release create v1'
no 'gh repo edit'
no "gh issue create --body \"\$(cat <<'EOF'
x
EOF
git push
EOF
)\""

# gh api GET and heredoc bodies
ok 'gh api -X GET repos/o/r'
ok 'gh api --method GET search/issues -f q=x'
ok 'gh api -XGET repos/o/r'
ok 'gh api --method=GET repos/o/r'
no 'gh api -X GET -X POST repos/o/r'
no 'gh api -XPOST repos/o/r'
no 'gh api --method=PATCH repos/o/r'
ok 'gh api repos/o/foo-x'
no 'gh api -X DELETE repos/o/r -f "a= -X GET"'
no 'gh api -X GET a; gh api -X POST b'
ok "cat <<'EOF'
git push
it's \"x
rm -rf src
echo > src/a
EOF"
ok 'cat > /tmp/x <<EOF
git commit -m x
EOF
ls'
ok "cat >> /tmp/x <<-'EOF' | wc -l
	kill 1
	EOF"
ok "gh issue create -t x -F - <<'EOF'
git push
EOF"
no "cat > src/a <<'EOF'
x
EOF"
no 'cat <<EOF
$(git push)
EOF'
no 'cat <<EOF
`git push`
EOF'
no 'cat <<EOF
x
EOF
git push'
for sh in 'bash <<EOF' 'sh -s <<EOF' 'python3 - <<EOF' "bash <<'EOF'" 'cat <<EOF | bash' "cat <<'EOF' 2>&1 | bash" "cat <<'EOF' >&1 | bash" 'cat <<EOF &> /tmp/x | bash' 'gh alias import - <<EOF' 'cat <<EOF | sort --compress-program=sh' 'cat <<EOF |' '$SHELL <<EOF' './x <<EOF' 'bash <(cat <<EOF' 'cat <<EOF > >(bash)'; do
  no "$sh
git push
EOF
"
done
ok 'python3 - <<EOF
print("run `make x` now")
EOF'
no '{
cat <<EOF
git push
EOF
} 2>&1 | bash'
no '$(
cat <<EOF
git push
EOF
)'
no 'echo hi # <<EOF
git push
EOF'
no '(( x = 1<<EOF ))
git push
EOF'
no "cat <<A <<B
A
cat <<X
B
git push
X"
no 'cat <<EOF-1
EOF-1
git push
EOF'
no 'cat <<\EOF
EOF
git push'

# size: 300 KB, judged before the hook could time out
big() { perl -e 'print $ARGV[0] x $ARGV[1]' -- "$1" "$2"; }
for c in "cat > /tmp/x <<'EOF'
$(big 'git commit it
' 22000)
EOF" "$(big 'rm /tmp/a/b; ' 23000)" "$(big 'echo hi; ' 33000)" "gh issue comment 1 -b '$(big 'a; b (c) ' 33000)'"; do
  jq -n --rawfile c <(printf %s "$c") '{session_id: "lead1", tool_name: "Bash", cwd: "/tmp", tool_input: {command: $c}}' >"$TMP_H/big.json"
  SECONDS=0
  bash "$HOOK" <"$TMP_H/big.json" >/dev/null
  assert "a 300 KB command is judged in time (${c:0:20})" '[ "$SECONDS" -le 2 ]'
done
no "$(big 'echo hi; ' 9000)git push"
assert "deny names the coordination rights" 'grep -q "git add" <<<"$OUT" && grep -q "gh issue" <<<"$OUT"'

echo "=== lead-guard: design + browser ==="
# section: lead-guard-mcp
PAPER_WRITES=$(grep -oE 'mcp__paper__[a-z_]+' "$HOOK" | sort -u | tr '\n' ' ')
assert "lead-guard lists the 16 Paper write tools" '[ "$(wc -w <<<"$PAPER_WRITES")" -eq 16 ]'
for t in $PAPER_WRITES; do
  OUT=$(fire lead1 "$t" '{}')
  assert "$t is denied" '[ -n "$OUT" ]'
done
OUT=$(fire lead1 mcp__paper__write_html '{}')
assert "paper deny names Paper and ai:designer" 'grep -q "Paper" <<<"$OUT" && grep -q "ai:designer" <<<"$OUT"'
for t in get_screenshot get_basic_info get_computed_styles get_jsx get_tokens export finish_working_on_nodes; do
  OUT=$(fire lead1 "mcp__paper__$t" '{}')
  assert "paper $t is silent" '[ -z "$OUT" ]'
done
OUT=$(fire lead1 mcp__pencil__execute '{}')
assert "pencil execute is no longer guarded" '[ -z "$OUT" ]'
OUT=$(fire lead1 mcp__claude-in-chrome__computer '{}')
assert "chrome computer is denied" '[ -n "$OUT" ]'
for a in screenshot zoom; do
  OUT=$(fire lead1 mcp__claude-in-chrome__computer "{\"action\":\"$a\"}")
  assert "chrome computer $a is silent" '[ -z "$OUT" ]'
done
for a in left_click type key scroll screenshot_x; do
  OUT=$(fire lead1 mcp__claude-in-chrome__computer "{\"action\":\"$a\"}")
  assert "chrome computer $a is denied" '[ -n "$OUT" ]'
done
OUT=$(fire lead1 mcp__claude-in-chrome__browser_batch '{"action":"screenshot"}')
assert "chrome browser_batch is denied" '[ -n "$OUT" ]'
OUT=$(fire lead1 mcp__claude-in-chrome__read_page '{}')
assert "chrome read_page is silent" '[ -z "$OUT" ]'
OUT=$(fire lead1 mcp__claude-in-chrome__navigate '{}')
assert "chrome navigate is denied" '[ -n "$OUT" ]'
assert "reason counts browser actions and package runners as work" 'grep -q "browser actions and package runners count as work" <<<"$OUT"'

echo "=== lead-guard: failure safety ==="
# section: lead-guard-safety
set +e
EMPTY_OUT=$(bash "$HOOK" </dev/null 2>&1)
EMPTY_RC=$?
JUNK_OUT=$(echo 'not json' | bash "$HOOK" 2>&1)
JUNK_RC=$?
set -e
assert "empty payload exits 0 silent" '[ "$EMPTY_RC" -eq 0 ] && [ -z "$EMPTY_OUT" ]'
assert "malformed payload exits 0 silent" '[ "$JUNK_RC" -eq 0 ] && [ -z "$JUNK_OUT" ]'
rm -rf "$TMP_H"

echo "=== lead-guard: plugin delivery ==="
# section: lead-guard-plugin
HOOKS_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "hooks.json registers lead-guard on PreToolUse for every guarded tool" \
  'python3 -c "
import json, re, sys
d = json.load(open(\"$HOOKS_JSON\"))
b = [b for b in d[\"hooks\"][\"PreToolUse\"] if any(h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/bin/hooks/lead-guard.sh\" for h in b[\"hooks\"])]
assert len(b) == 1, b
for t in [\"Edit\", \"Write\", \"MultiEdit\", \"NotebookEdit\", \"Bash\", \"mcp__claude-in-chrome__computer\"] + sys.argv[1:]:
    assert re.fullmatch(b[0][\"matcher\"], t), t
for t in [\"mcp__pencil__execute\", \"mcp__paper__get_screenshot\"]:
    assert not re.fullmatch(b[0][\"matcher\"], t), t
" $PAPER_WRITES'

print_summary_and_exit
