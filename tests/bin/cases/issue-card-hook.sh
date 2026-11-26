#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

HOOK="$AIKIT/bin/hooks/issue-card.sh"
unset CLAUDE_PROJECT_DIR GH_REPO

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
git config --global init.defaultBranch main
KIT_T="$AIKIT/context/templates/github/ISSUE_TEMPLATE"

# Kills the whole process group after 3s, so a hang is a failure, never a stuck run.
LIMIT='my $p = fork // exit 1; if (!$p) { setpgrp(0, 0); exec @ARGV; exit 127 }
  $SIG{ALRM} = sub { kill "KILL", -$p; exit 124 }; alarm 3; waitpid $p, 0; exit($? >> 8)'
pre() {
  # pre <cwd> <command> -> deny reason, empty if silent; "HANG" past the limit
  jq -n --arg c "$2" --arg d "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' >"$TMP/in.json"
  perl -e "$LIMIT" bash "$HOOK" <"$TMP/in.json" 2>"$TMP/err" >"$TMP/out.json" || { echo HANG; return; }
  jq -r 'select(.hookSpecificOutput.permissionDecision == "deny") | .hookSpecificOutput.permissionDecisionReason' "$TMP/out.json"
}
silent() { OUT=$(pre "$2" "$3"); assert "$1" '[ -z "$OUT" ]'; }
# denied <name> <cwd> <command> [<fixed string in the reason>]
denied() { OUT=$(pre "$2" "$3"); WANT="${4:-issue-card [}"; assert "$1" 'grep -qF -- "$WANT" <<<"$OUT"'; }

mkrepo() {
  # mkrepo <dir> <wired|skipped|none> <template>...
  local d="$1" mode="$2"; shift 2
  mkdir -p "$d/.github/ISSUE_TEMPLATE" "$d/sub"
  git -C "$d" init -q
  git -C "$d" remote add origin git@github.com:Acme/demo.git
  [ "$mode" = none ] || printf '{"branches": {"issue_card_hook": "%s"}}\n' "$mode" >"$d/.ai-kit-setup"
  local t
  for t in "$@"; do cp "$KIT_T/$t" "$d/.github/ISSUE_TEMPLATE/"; done
}
# body_of <template> -> its text without frontmatter
body_of() { awk 'n >= 2; /^---$/ { n++ }' "$KIT_T/$1"; }

NL="$TMP/nl"; mkrepo "$NL" wired epic.md story.md task.md bug.md spike.md idea.md
EN="$TMP/en"; mkrepo "$EN" wired epic.en.md story.en.md task.en.md bug.en.md spike.en.md idea.en.md
B="$TMP/bodies"; mkdir -p "$B"
for t in "$KIT_T"/*.md; do n="$(basename "$t")"; body_of "$n" >"$B/$n"; done

echo "=== issue-card: complete bodies pass ==="
# section: issue-card-complete
COPY="$TMP/plugin/bin"
mkdir -p "$COPY/hooks" "$COPY/lib"
cp "$AIKIT/bin/hooks/issue-card.sh" "$COPY/hooks/" 2>/dev/null || true
cp "$AIKIT/bin/lib/issue-card.pl" "$AIKIT/bin/lib/setup-marker.sh" "$AIKIT/bin/lib/shell-mask.sh" "$COPY/lib/" 2>/dev/null || true
cat >"$COPY/ai-kit-issue-meta.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TMP/meta.log"
[ -z "\${META_SLEEP:-}" ] || sleep "\$META_SLEEP"
echo "\${META_OUT:-issue-meta: #7 set type, board}" >&2
exit "\${META_RC:-0}"
STUB
post() {
  # post <cwd> <command> <stdout> -> additionalContext; the calls land in META
  : >"$TMP/meta.log"
  CTX=$(jq -n --arg c "$2" --arg d "$1" --arg o "$3" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d,
      tool_response: {stdout: $o, stderr: "", interrupted: false, isImage: false}}' |
    bash "$COPY/hooks/issue-card.sh") && RC=0 || RC=$?
  BLOCK=$(jq -r '.decision // empty' <<<"$CTX")
  CTX=$(jq -r '.hookSpecificOutput | select(.hookEventName == "PostToolUse") | .additionalContext' <<<"$CTX")
  META=$(cat "$TMP/meta.log")
}
U=https://github.com/acme/demo/issues
for pair in epic:Epic story:Story task:Task bug:Bug spike:Task idea:Task; do
  n="${pair%%:*}"
  PA=" --parent 40"; [[ $n =~ ^(epic|spike|idea)$ ]] && PA=""
  WANT="$U/7 --only-unset --status Backlog --type ${pair#*:}$PA"
  for lang in "$NL $n.md" "$EN $n.en.md"; do
    C="gh issue create --title x --body-file $B/${lang#* }$PA"
    OUT=$(pre "${lang% *}" "$C")
    post "${lang% *}" "$C" "$U/7"
    assert "${lang#* } passes and gives ${pair#*:} in Backlog" '[ -z "$OUT" ] && [ "$META" = "$WANT" ]'
  done
done
denied "an en body in an nl repo is denied" "$NL" "gh issue create -t x -F $B/bug.en.md" "lacks ## "
printf '## WAT\n\nx\n\n## Extra heading\n\n##   waarom ##\n\n## Wanneer oppakken (datum)\n' >"$B/case.md"
silent "case, parenthetical suffix, closing hashes and extra headings are fine" "$NL" "gh issue create -t x -F $B/case.md"
sed 's/$/\r/' "$B/bug.md" >"$B/crlf.md"
silent "CRLF body passes" "$NL" "gh issue create -t x -F $B/crlf.md --parent 40"
printf -- '---\nname: Uitleg\n---\nGeen koppen.\n' >"$NL/.github/ISSUE_TEMPLATE/plain.md"
denied "a template without headings passes nothing" "$NL" "gh issue create -t x -b hi" "## Wat"
rm "$NL/.github/ISSUE_TEMPLATE/plain.md"

echo "=== issue-card: missing headings ==="
# section: issue-card-missing
grep -v '^## Waar$' "$B/bug.md" | sed 's/^## Definition of Done.*//' >"$B/partial.md"
OUT=$(pre "$NL" "gh issue create -t x -F $B/partial.md")
assert "reason names the missing headings" 'grep -qF "## Waar" <<<"$OUT" && grep -qF "## Definition of Done" <<<"$OUT" && ! grep -qF "## Stappen" <<<"$OUT"'
assert "reason names the closest template" 'grep -qF ".github/ISSUE_TEMPLATE/bug.md" <<<"$OUT"'
printf '## Wat\n\n## Waarom\n\n```md\n## Wanneer oppakken\n```\n' >"$B/fence.md"
denied "a heading in a code fence does not count" "$NL" "gh issue create -t x -F $B/fence.md" "## Wanneer oppakken"
printf '## Wat\n\n## Waarom\n\n~~~~\n```\n## Wanneer oppakken\n~~~~\n' >"$B/fence2.md"
denied "a heading in a tilde fence does not count" "$NL" "gh issue create -t x -F $B/fence2.md" "## Wanneer oppakken"
printf '## Wat\n\n## Waarom\n\n<!-- draft\n## Wanneer oppakken\n-->\n' >"$B/comment.md"
denied "a heading in an HTML comment does not count" "$NL" "gh issue create -t x -F $B/comment.md" "## Wanneer oppakken"
# shellcheck disable=SC2016
printf '## Wat\n\nDe tekst `<!--` in code.\n\n## Waarom\n\n### Wanneer oppakken\n' >"$B/h3.md"
denied "an H3 does not count" "$NL" "gh issue create -t x -F $B/h3.md" "## Wanneer oppakken"
sed 's/^### /## /' "$B/h3.md" >"$B/codecomment.md"
silent "a comment opener in inline code hides no heading" "$NL" "gh issue create -t x -F $B/codecomment.md"
denied "a literal --body is checked" "$NL" 'gh issue create --title x --body "## Wat"' "## Waarom"
silent "a complete literal --body passes" "$NL" $'gh issue create --title x --body=\'## Wat\n\n## Waarom\n\n## Wanneer oppakken\n\''
denied "gh issue new is the same command" "$NL" "gh issue new -t x -b hi"

echo "=== issue-card: card marker line ==="
# section: issue-card-other
printf '<!-- card: other -->\n\nReport\n' >"$B/other.md"
silent "card: other passes" "$NL" "gh issue create -t x -F $B/other.md"
# shellcheck disable=SC2016
printf 'Text `<!-- card: other -->` inline\n' >"$B/inline.md"
denied "card: other inside a sentence does not pass" "$NL" "gh issue create -t x -F $B/inline.md"
printf '```\n<!-- card: other -->\n```\n' >"$B/otherfence.md"
denied "card: other in a fence does not pass" "$NL" "gh issue create -t x -F $B/otherfence.md"

echo "=== issue-card: parent epic ==="
# section: issue-card-parent
OUT=$(pre "$NL" "gh issue create -t x -F $B/story.md")
assert "a story without --parent is denied where an epic template exists" 'grep -qF -- "issue-card [no parent]:" <<<"$OUT"'
assert "the reason names the area epic, the maintenance epic and the escape line" 'grep -qF -- "--parent <epic>" <<<"$OUT" && grep -qF "area" <<<"$OUT" && grep -qF "maintenance epic" <<<"$OUT" && grep -qF "<!-- parent: none -->" <<<"$OUT"'
{ cat "$B/story.md"; printf '\n<!-- parent: none -->\n'; } >"$B/noparent.md"
silent "a parent: none line passes without --parent" "$NL" "gh issue create -t x -F $B/noparent.md"
{ cat "$B/story.md"; printf '\n```\n<!-- parent: none -->\n```\n'; } >"$B/noparentfence.md"
denied "a parent: none line in a fence does not pass" "$NL" "gh issue create -t x -F $B/noparentfence.md" "[no parent]"
denied "of two creates, the one without --parent is denied" "$NL" "gh issue create -t x -F $B/story.md --parent 40 && gh issue create -t y -F $B/bug.md" "a Bug card"
denied "an en bug without --parent is denied" "$EN" "gh issue create -t x -F $B/bug.en.md" "[no parent]"
denied "a task without --parent is denied" "$NL" "gh issue create -t x -F $B/task.md" "[no parent]"
silent "a story with --parent passes" "$NL" "gh issue create -t x -F $B/story.md --parent 40"
silent "a variable --parent counts as a parent" "$NL" 'gh issue create -t x -F '"$B"'/story.md --parent "$E"'
silent "an epic needs no parent" "$NL" "gh issue create -t x -F $B/epic.md"
silent "an idea needs no parent" "$NL" "gh issue create -t x -F $B/idea.md"
silent "a spike needs no parent" "$EN" "gh issue create -t x -F $B/spike.en.md"
silent "card: other needs no parent" "$NL" "gh issue create -t x -F $B/other.md"
mkrepo "$TMP/noepic" wired story.md bug.md
silent "a repo without an epic template needs no parent" "$TMP/noepic" "gh issue create -t x -F $B/story.md"

echo "=== issue-card: off ==="
# section: issue-card-off
BAD="gh issue create -t x -b hi"
mkrepo "$TMP/skipped" skipped story.md
mkrepo "$TMP/nomarker" none story.md
mkrepo "$TMP/nokey" none story.md; echo '{"branches": {}}' >"$TMP/nokey/.ai-kit-setup"
mkrepo "$TMP/yml" wired; echo 'name: Bug' >"$TMP/yml/.github/ISSUE_TEMPLATE/bug.yml"
mkdir -p "$TMP/norepo"
for d in skipped nomarker nokey yml norepo; do silent "$d is silent" "$TMP/$d" "$BAD"; done
denied "control: wired is denied" "$NL" "$BAD"
SENT="$TMP/sentinel"
mkdir -p "$SENT"
printf '#!/bin/sh\necho ran >>"%s/log"\nexec %s "$@"\n' "$SENT" "$(command -v perl)" >"$SENT/perl"
chmod +x "$SENT/perl"
mkfifo "$B/fifo.md"
for d in skipped nomarker nokey yml wired-control; do
  : >"$SENT/log"
  D="$TMP/$d"; [ "$d" = wired-control ] && D="$NL"
  jq -n --arg d "$D" --arg c "gh issue create -t x -F $B/fifo.md" '{hook_event_name: "PreToolUse", tool_input: {command: $c}, cwd: $d}' >"$TMP/in.json"
  RC=0; "$(command -v perl)" -e "$LIMIT" env PATH="$SENT:$PATH" bash "$HOOK" <"$TMP/in.json" >/dev/null 2>&1 || RC=$?
  if [ "$d" = wired-control ]; then
    assert "control: a wired repo runs the parser" '[ "$RC" -eq 0 ] && [ -s "$SENT/log" ]'
  else
    assert "$d: no parser runs, so the body file is never opened" '[ "$RC" -eq 0 ] && [ ! -s "$SENT/log" ]'
  fi
done
for tool in jq perl none; do
  mkdir -p "$TMP/no-$tool"
  for x in bash cat dirname git python3 jq perl tr; do
    [ "$x" = "$tool" ] || ln -s "$(command -v "$x")" "$TMP/no-$tool/$x"
  done
  OUT=$(jq -n --arg c "$BAD" --arg d "$NL" '{hook_event_name: "PreToolUse", tool_input: {command: $c}, cwd: $d}' |
    PATH="$TMP/no-$tool" bash "$HOOK" 2>&1) || true
  if [ "$tool" = none ]; then
    assert "control: the same PATH with every tool denies" 'grep -q "deny" <<<"$OUT"'
  else
    assert "without $tool the hook is silent" '[ -z "$OUT" ]'
  fi
done

echo "=== issue-card: other repo ==="
# section: issue-card-repo
for f in "--repo other/app" "-R other/app" "--repo=github.com/other/app" "-R https://github.com/other/app"; do
  silent "$f is let through" "$NL" "$BAD $f"
done
silent "GH_REPO prefix naming another repo is let through" "$NL" "GH_REPO=other/app $BAD"
denied "--repo naming this repo is checked, case aside" "$NL" "$BAD --repo acme/Demo"
denied "cd into a gated repo, ended by ;" "$TMP/nomarker" "cd $NL/sub; $BAD" "missing headings"
denied "cd into a gated repo, ended by a newline" "$TMP/nomarker" "cd $NL/sub"$'\n'"$BAD" "missing headings"
silent "cd into a repo without the marker, ended by ;" "$NL" "cd $TMP/nomarker; $BAD"
silent "cd into a repo without the marker is let through" "$NL" "cd $TMP/nomarker && $BAD"
denied "cd into a gated repo is checked" "$TMP/nomarker" "cd $NL/sub && $BAD"
denied "an unknown cd target counts as the call's cwd" "$NL" 'cd "$(git rev-parse --show-toplevel)" && '"$BAD"

echo "=== issue-card: unreadable bodies ==="
# section: issue-card-unreadable
P="issue-card [unreadable]:"
OUT=$(pre "$NL" "gh issue create -t x")
assert "the unreadable reason gives an example to copy" 'grep -qF "gh issue create --title \"Title\" --body-file /tmp/issue-body.md" <<<"$OUT"'
OUT=$(pre "$NL" "gh issue create -t x -b hi")
assert "missing headings carry their own label" 'grep -qF "issue-card [missing headings]:" <<<"$OUT" && ! grep -qF unreadable <<<"$OUT"'
{ body_of idea.md; head -c 65536 /dev/zero | tr '\0' x; } >"$B/big.md"
{ body_of idea.md; head -c 4194304 /dev/zero | tr '\0' x; } >"$B/huge.md"
{ body_of idea.md; head -c 60000 /dev/zero | tr '\0' x; } >"$B/fits.md"
silent "a 60000 character body is read" "$NL" "gh issue create -t x -F $B/fits.md"
printf '## Wat\0\n\n## Waarom\n\n## Wanneer oppakken\n' >"$B/nul.md"
silent "NUL bytes are stripped" "$NL" "gh issue create -t x -F $B/nul.md"
silent "--web=true too" "$NL" "gh issue create --web=true"
denied "--web=false is not web" "$NL" "gh issue create --web=false -t x -b hi" "## "
denied "a variable body" "$NL" 'gh issue create -t x --body "$BODY"' "$P"
denied "a command substitution body" "$NL" 'gh issue create -t x --body "$(cat f.md)"' "$P"
denied "a heredoc in a command substitution" "$NL" $'gh issue create -t x --body "$(cat <<\'EOF\'\n## Wat\n## Waarom\n## Wanneer oppakken\nEOF\n)"' "$P"
# shellcheck disable=SC2016
denied "backticks in a double-quoted body" "$NL" 'gh issue create -t x --body "## Wat `id`"' "$P"
denied "a variable path" "$NL" 'gh issue create -t x --body-file "$F"' "$P"
denied "a missing file" "$NL" "gh issue create -t x -F $B/nope.md" "$P"
denied "--template" "$NL" "gh issue create -t x --template Bug" "$P"
denied "no body at all" "$NL" "gh issue create -t x" "$P"
denied "a heredoc on stdin" "$NL" $'gh issue create -t x -F - <<\'EOF\'\n## Wat\n## Waarom\n## Wanneer oppakken\nEOF' "$P"
denied "a bundled short flag" "$NL" "gh issue create -tx -F$B/idea.md" "$P"
denied "a variable --repo" "$NL" 'gh issue create -t x -b hi -R "$R"' "$P"
denied "a body file over 65536 characters" "$NL" "gh issue create -t x -F $B/big.md" "$P"
denied "a directory" "$NL" "gh issue create -t x -F $B" "$P"
denied "a FIFO" "$NL" "gh issue create -t x -F $B/fifo.md" "$P"
denied "/dev/zero" "$NL" "gh issue create -t x -F /dev/zero" "$P"
denied "a 4 MB file" "$NL" "gh issue create -t x -F $B/huge.md" "$P"
denied "piped stdin" "$NL" "cat $B/bug.md | gh issue create -t x -F -" "$P"
silent "--web is a person's browser" "$NL" "gh issue create --web"
silent "-w too" "$NL" "gh issue create -w -t x"
cp "$B/idea.md" "$NL/sub/rel.md"
silent "a path relative to the cwd" "$NL/sub" "gh issue create -t x -F rel.md"
silent "a path relative to cd" "$NL" "cd sub && gh issue create -t x -F ./rel.md"

echo "=== issue-card: every create, wherever it stands ==="
# section: issue-card-chains
OK="gh issue create -t x -F $B/idea.md"
silent "two complete creates" "$NL" "$OK && $OK"
denied "the second of two is checked" "$NL" "$OK && gh issue create -t y -b hi"
denied "inside a command substitution" "$NL" 'URL=$(gh issue create -t x -b hi); echo "$URL"'
denied "in a loop" "$NL" 'for i in 1 2; do gh issue create -t x -b hi; done'
denied "in a quoted command substitution" "$NL" 'URL="$(gh issue create -t "a b" -b hi)"; echo "$URL"'
denied "in a subshell" "$NL" '(gh issue create -t x -b hi)'
denied "across a line continuation" "$NL" $'gh issue create \\\n  --title x \\\n  --body hi 2>&1 | tail -1'
denied "behind env and rtk" "$NL" 'env FOO=1 rtk gh issue create -t x -b hi'
denied "behind env -u" "$NL" 'env -u GITHUB_TOKEN gh issue create -t x -b hi'
denied "after a heredoc" "$NL" $'cat <<EOF\nit\'s\nEOF\ngh issue create -t x -b hi'
denied "after a shift in arithmetic" "$NL" $'echo $((1<<3))\ngh issue create -t x -b hi'

echo "=== issue-card: decoys ==="
# section: issue-card-decoys
silent "in a quoted string" "$NL" "echo 'gh issue create -t x -b hi'"
silent "in a double-quoted string with separators" "$NL" 'git commit -m "a; gh issue create -b hi"'
silent "in another command's heredoc" "$NL" $'cat > /dev/null <<\'EOF\'\ngh issue create -t x -b hi\nEOF'
silent "in a comment" "$NL" "ls # gh issue create -t x"
silent "as another command's arguments" "$NL" "grep -rn gh issue create ."
silent "command -v" "$NL" "command -v gh issue create"
silent "type" "$NL" "type gh issue create"
silent "a comment with a separator" "$NL" "ls # then; gh issue create -t x"
silent "a flag value that names a flag" "$NL" "gh issue create -t --web -F $B/idea.md"
silent "--help" "$NL" "gh issue create --help"
silent "another gh issue verb" "$NL" "gh issue list --search 'issue create'"
silent "another gh command" "$NL" "gh pr create -t 'gh issue create' -b hi"
silent "a flag value" "$NL" "gh issue comment 4 --body create"

echo "=== issue-card: unfinished shell returns in time ==="
# section: issue-card-hang
# returns <name> <command>: silent or denied, but not a hang
returns() { OUT=$(pre "$NL" "$2"); assert "$1 returns within 3s" '[ "$OUT" != HANG ]'; }
returns "an unterminated quote" 'gh issue create -t "x -b hi'
returns "an unterminated substitution" 'gh issue create -b $(cat'
returns "an unterminated paren" '(gh issue create -b hi'
returns "an unterminated heredoc" $'gh issue create -F - <<EOF\nx'
returns "a shift in bare arithmetic" $'((i=1<<s))\ngh issue create -b hi'
returns "an endless for" 'for ((;;)); do gh issue view 1; done; gh issue create -b hi'
OPENERS="$(printf '%3000s' '' | sed 's/ /"$((/g')"
returns "many openers" "gh issue create -b hi $OPENERS"
OPENERS="$(printf '%3000s' '' | tr ' ' '(')"
returns "many open parens" "gh issue create -b hi \$$OPENERS"
silent "for ((;;)) with gh issue view" "$NL" 'for ((;;)); do gh issue view 1; done'
cp "$AIKIT/bin/lib/issue-card.pl" "$TMP/real.pl" 2>/dev/null || true
echo 'alarm 1; 1 while 1;' >"$COPY/lib/issue-card.pl"
cp "$AIKIT/bin/hooks/issue-card.sh" "$COPY/hooks/"
HOOK="$COPY/hooks/issue-card.sh"
OUT=$(pre "$NL" "gh issue create -t x -b hi")
assert "a parser past its alarm fails open with a message" '[ -z "$OUT" ] && grep -q "issue-card: .*not checked" "$TMP/err"'
HOOK="$AIKIT/bin/hooks/issue-card.sh"
cp "$TMP/real.pl" "$COPY/lib/issue-card.pl"

echo "=== issue-card: after the create ==="
# section: issue-card-post
post "$NL" "gh issue create -t x -F $B/bug.md" "$U/7"
assert "the result reaches the model" 'grep -qF "issue-meta: #7 set type, board" <<<"$CTX"'
post "$NL" "gh issue create -t x -F $B/story.md --parent 40" "$U/7"
assert "the parent is passed on" '[ "$META" = "$U/7 --only-unset --status Backlog --type Story --parent 40" ]'
post "$NL" "gh issue create -t x -F $B/other.md" "Creating issue in acme/demo"$'\n\n'"$U/7"
assert "card: other sets no type" '[ "$META" = "$U/7 --only-unset --status Backlog" ]'
post "$NL" 'gh issue create -t x -F "$F"' "$U/7"
assert "an unreadable body sets no type" '[ "$META" = "$U/7 --only-unset --status Backlog" ]'
mkrepo "$TMP/legacy" wired story.md; mv "$TMP/legacy/.github/ISSUE_TEMPLATE/story.md" "$TMP/legacy/.github/ISSUE_TEMPLATE/feature.md"
post "$TMP/legacy" "gh issue create -t x -F $B/story.md" "$U/7"
assert "a template with an unknown name sets no type" '[ "$META" = "$U/7 --only-unset --status Backlog" ]'
cp "$NL/.github/ISSUE_TEMPLATE/story.md" "$TMP/legacy/.github/ISSUE_TEMPLATE/story.md"
post "$TMP/legacy" "gh issue create -t x -F $B/story.md" "$U/7"
assert "two equal matches with different types set no type" '[ "$META" = "$U/7 --only-unset --status Backlog" ]'
post "$NL" "gh issue create -t x -F $B/bug.md; gh issue create -t y -F $B/idea.md" "$U/7"$'\n'"$U/8"
assert "two creates pair with their URLs" '[ "$META" = "$U/7 --only-unset --status Backlog --type Bug
$U/8 --only-unset --status Backlog --type Task" ]'
post "$NL" "gh issue create -t x -F $B/bug.md; gh issue list" "$U/7"$'\n'"$U/8"
assert "more URLs than creates sets nothing and says so" '[ -z "$META" ] && [ -n "$CTX" ]'
post "$NL" "gh issue create -t x -F $B/bug.md || true" "HTTP 403"
assert "no URL sets nothing and says so" '[ -z "$META" ] && [ -n "$CTX" ]'
post "$NL" "gh issue create -t x -F $B/bug.md" "$U/7#issuecomment-1 $U/7"
assert "a comment link is not a second URL" '[ "$META" = "$U/7 --only-unset --status Backlog --type Bug" ]'
post "$NL" "gh issue create -t x -F $B/bug.md -R other/app" "https://github.com/other/app/issues/7"
assert "another repo sets nothing" '[ -z "$META$CTX" ]'
post "$NL" "gh issue list" "$U/7"
assert "another command sets nothing" '[ -z "$META$CTX" ]'
for d in skipped yml; do
  post "$TMP/$d" "gh issue create -t x -F $B/bug.md" "$U/7"
  assert "$d sets nothing" '[ -z "$META$CTX" ]'
done
export META_RC=2 META_OUT="issue-meta: boom"
post "$NL" "gh issue create -t x -F $B/bug.md" "$U/7"
assert "a failing issue-meta is a message, not a block" '[ "$RC" -eq 0 ] && [ -z "$BLOCK" ] && grep -qF "issue-meta: boom" <<<"$CTX"'
unset META_RC META_OUT
export META_SLEEP=30 AI_KIT_ISSUE_CARD_TIMEOUT=1
SECONDS=0
post "$NL" "gh issue create -t x -F $B/bug.md" "$U/7"
assert "a hanging issue-meta is cut off with a message" '[ "$RC" -eq 0 ] && [ "$SECONDS" -lt 15 ] && grep -qF "timed out" <<<"$CTX"'
unset META_SLEEP AI_KIT_ISSUE_CARD_TIMEOUT
OUT=$(jq -n --arg c "gh issue create -t x -F $B/bug.md" --arg d "$NL" \
  '{hook_event_name: "PostToolUse", tool_input: {command: $c}, cwd: $d, tool_response: "Error: x"}' | bash "$COPY/hooks/issue-card.sh") && RC=0 || RC=$?
assert "a string tool_response does not crash" '[ "$RC" -eq 0 ] && [ -z "$(jq -r ".decision // empty" <<<"$OUT")" ]'

echo "=== issue-card: marker and plugin delivery ==="
# section: issue-card-plugin
bash "$AIKIT/bin/write-setup-marker.sh" "$TMP/nokey" --issue-card-hook=wired >/dev/null 2>&1 || true
assert "write-setup-marker records --issue-card-hook" '[ "$(jq -r .branches.issue_card_hook "$TMP/nokey/.ai-kit-setup")" = wired ]'
assert "the kit does not turn it on here" '[ "$(jq -r ".branches.issue_card_hook // empty" "$AIKIT/.ai-kit-setup")" != wired ]'
assert "hooks.json registers issue-card on PreToolUse and PostToolUse Bash, both bounded" \
  'python3 -c "
import json
d = json.load(open(\"$AIKIT/workflow/hooks/hooks.json\"))
hits = [(ev, b[\"matcher\"], h.get(\"timeout\")) for ev, bs in d[\"hooks\"].items() for b in bs for h in b[\"hooks\"]
        if h[\"command\"] == \"\${CLAUDE_PLUGIN_ROOT}/bin/hooks/issue-card.sh\"]
assert hits == [(\"PreToolUse\", \"Bash\", 5), (\"PostToolUse\", \"Bash\", 60)], hits
"'

print_summary_and_exit
