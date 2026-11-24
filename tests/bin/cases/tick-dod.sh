#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

T=$(mktemp -d)
mkdir -p "$T/stubs"
# Serves $STUB/body.md, or $STUB/body2.md from the second read on; an edit lands in $STUB/written.md.
cat > "$T/stubs/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "issue view")
    echo read >> "$STUB/reads"
    f="$STUB/body.md"
    [ "$(wc -l < "$STUB/reads")" -gt 1 ] && [ -f "$STUB/body2.md" ] && f="$STUB/body2.md"
    [ -f "$f" ] || { echo "no such issue" >&2; exit 1; }
    python3 -c 'import json,sys; print(json.dumps({"body": open(sys.argv[1], newline="", encoding="utf-8").read()}))' "$f" ;;
  "issue edit")
    [ ! -f "$STUB/edit-fails" ] || { echo "HTTP 403" >&2; exit 1; }
    [ "$4" = --body-file ] || exit 9
    command cp "$5" "$STUB/written.md" ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$T/stubs/gh"

# $1 = case name; stdin = the boxes file.
tick() {
  RC=0
  cat > "$T/$1/boxes"
  OUT="$(STUB="$T/$1" PATH="$T/stubs:$PATH" "$AIKIT/bin/ai-kit-tick-dod.sh" 42 "$T/$1/boxes" 2>&1)" || RC=$?
}
TPL="$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE"

echo "=== ai-kit-tick-dod: listed boxes only, nl and en ==="
for f in story.md story.en.md bug.md epic.md epic.en.md; do
  mkdir -p "$T/$f"
  command cp "$TPL/$f" "$T/$f/body.md"
  BOX="$(sed -n '/^## Definition of Done/,$p' "$TPL/$f" | sed -n 's/^- \[ \] //p' | head -1)"
  tick "$f" <<<"$BOX"
  assert "$f: exit 0" '[ "$RC" -eq 0 ]'
  assert "$f: one line changed, only its checkbox" \
    '[ "$(diff "$T/$f/body.md" "$T/$f/written.md" | grep -c "^[<>]")" -eq 2 ] && grep -qxF -- "- [x] $BOX" "$T/$f/written.md"'
  assert "$f: names the boxes still open" 'grep -q "^open: " <<<"$OUT" && ! grep -qxF "open: $BOX" <<<"$OUT"'
done
tick epic.md <<<"$(sed -n '/^## Klaar/,/^## Buiten/s/^- \[ \] //p' "$TPL/epic.md")"
assert "done when: the same line twice needs listing twice, then both tick" \
  '[ "$RC" -eq 0 ] && [ "$(grep -c "^- \[x\]" "$T/epic.md/written.md")" -eq 2 ]'

echo "=== ai-kit-tick-dod: exact text ==="
mkdir -p "$T/exact"
printf '## Definition of Ready\n- [ ] Same\n\n## Acceptance criteria\n- [ ] Runs `a|b` (proof: test "x")\n- [ ] Runs `a|b` (proof: test "x") twice\n\n## Definition of Done (before close)\n- [ ] Same\n- [X] Already\n\n## Notes\n- [ ] Note\n' > "$T/exact/body.md"
tick exact <<'B'
Same
Runs `a|b` (proof: test "x")
Already
B
assert "text with markdown matches literally, a longer box stays open" \
  'grep -qxF -- "- [x] Runs \`a|b\` (proof: test \"x\")" "$T/exact/written.md" && grep -qxF -- "- [ ] Runs \`a|b\` (proof: test \"x\") twice" "$T/exact/written.md"'
assert "the same text in the DoR stays open" '[ "$(sed -n 2p "$T/exact/written.md")" = "- [ ] Same" ] && [ "$(sed -n 9p "$T/exact/written.md")" = "- [x] Same" ]'
assert "an already ticked box keeps its mark" 'grep -qxF -- "- [X] Already" "$T/exact/written.md"'
command rm "$T/exact/written.md"
tick exact <<<"Note"
assert "a box outside criteria, done when and DoD is refused" '[ "$RC" -eq 1 ] && [ ! -e "$T/exact/written.md" ]'
tick exact <<<"$(printf 'Same\nsame')"
assert "one unknown box refuses the whole run" '[ "$RC" -eq 1 ] && [ ! -e "$T/exact/written.md" ] && grep -q "not on the card: same" <<<"$OUT"'
tick exact <<<"Already"
assert "nothing to tick: exit 0, no write" '[ "$RC" -eq 0 ] && [ ! -e "$T/exact/written.md" ] && grep -qx "open: Same" <<<"$OUT"'

echo "=== ai-kit-tick-dod: duplicate text ==="
mkdir -p "$T/dup"
printf '## Acceptance criteria\n- [ ] Green\n## Definition of Done\n- [ ] Green\n' > "$T/dup/body.md"
tick dup <<<"Green"
assert "listed once, on the card twice: refused" '[ "$RC" -eq 1 ] && [ ! -e "$T/dup/written.md" ] && grep -q "2 times" <<<"$OUT"'
tick dup <<<"$(printf 'Green\nGreen')"
assert "listed twice: both ticked" '[ "$RC" -eq 0 ] && [ "$(grep -c "^- \[x\] Green" "$T/dup/written.md")" -eq 2 ]'

echo "=== ai-kit-tick-dod: heading levels and fences ==="
mkdir -p "$T/levels"
printf '## Scope\n- [ ] Sub\n### Definition of Done\n- [ ] A\n#### Notes\n- [ ] Nested\n### Definition of Ready\n- [ ] Ready\n## Acceptance criteria\n- [ ] C\n# Other\n- [ ] Out\n' > "$T/levels/body.md"
tick levels <<<"A"
assert "an H3 DoD counts" '[ "$RC" -eq 0 ] && [ "$(sed -n 4p "$T/levels/written.md")" = "- [x] A" ]'
assert "a deeper heading stays in the section, an equal or higher one ends it" '[ "$(grep "^open: " <<<"$OUT" | paste -sd, -)" = "open: Nested,open: C" ]'
mkdir -p "$T/fence"
printf '## Definition of Done\n- [ ] A\n```md\n## Example\n- [ ] Fenced\n~~~\n```\n- [ ] B\n~~~~\n~~~\n- [ ] Fenced too\n~~~~\n- [ ] C\n## Notes\n```\n## Definition of Done\n```\n- [ ] N\n' > "$T/fence/body.md"
tick fence <<<"A"
assert "a fenced heading neither ends nor starts a section, fenced boxes do not count" \
  '[ "$RC" -eq 0 ] && [ "$(grep "^open: " <<<"$OUT" | paste -sd, -)" = "open: B,open: C" ]'
command rm -f "$T/fence/written.md"
tick fence <<<"Fenced"
assert "a fenced box is not ticked" '[ "$RC" -eq 1 ] && [ ! -e "$T/fence/written.md" ]'

echo "=== ai-kit-tick-dod: CRLF ==="
mkdir -p "$T/crlf"
printf '## Definition of Done (v\303\263\303\263r close)\r\n\r\n- [ ] E\303\251n (bewijs: x)\r\n- [ ] Twee\r\n' > "$T/crlf/body.md"
tick crlf <<<"Eén (bewijs: x)"
assert "CRLF: the box is ticked and every other byte stays" \
  '[ "$RC" -eq 0 ] && sed "s/\[x\] E/[ ] E/" "$T/crlf/written.md" | cmp -s - "$T/crlf/body.md" && [ "$(grep -c "\[x\]" "$T/crlf/written.md")" -eq 1 ]'

echo "=== ai-kit-tick-dod: refusals ==="
mkdir -p "$T/race"
printf '## Definition of Done\n- [ ] A\n' > "$T/race/body.md"
printf '## Definition of Done\n- [ ] A\n- [ ] B\n' > "$T/race/body2.md"
tick race <<<"A"
assert "a body that changed between read and write is refused" '[ "$RC" -eq 1 ] && [ ! -e "$T/race/written.md" ] && grep -q "changed" <<<"$OUT"'
mkdir -p "$T/fail"
tick fail <<<"A"
assert "a failed read exits 1 with gh's reason" '[ "$RC" -eq 1 ] && grep -q "no such issue" <<<"$OUT"'
command cp "$T/race/body.md" "$T/fail/body.md"; touch "$T/fail/edit-fails"
tick fail <<<"A"
assert "a failed write exits 1 with gh's reason, not a tick" '[ "$RC" -eq 1 ] && grep -q "HTTP 403" <<<"$OUT" && ! grep -q "ticked 1" <<<"$OUT"'
RC=0; "$AIKIT/bin/ai-kit-tick-dod.sh" 42 >/dev/null 2>&1 || RC=$?
assert "missing boxes file: exit 2" '[ "$RC" -eq 2 ]'
RC=0; "$AIKIT/bin/ai-kit-tick-dod.sh" --repo "$T/dup/boxes" >/dev/null 2>&1 || RC=$?
assert "a flag as issue: exit 2" '[ "$RC" -eq 2 ]'

echo "=== DoD bot reads what ticking wrote ==="
if command -v node >/dev/null 2>&1; then
  # The bot's own parser, cut from the workflow: prints how many DoD boxes it still sees unticked.
  bot_open() {
    { sed -n '/function extractSection/,/^            }/p' "$AIKIT/workflow/context/templates/github/workflows/dor-dod-enforcement.yml"
      echo 'const b = extractSection(require("fs").readFileSync(process.argv[2], "utf8"), "Definition of Done"); console.log(b.filter(x => !x.checked).length + "/" + b.length)'
    } > "$T/bot.js"
    node "$T/bot.js" "$1"
  }
  for f in story.md story.en.md; do
    sed -n '/^## Definition of Done/,$s/^- \[ \] //p' "$TPL/$f" > "$T/all"
    command rm -f "$T/$f/written.md"
    tick "$f" < "$T/all"
    assert "$f: untouched the bot sees all open, ticked none" '[ "$(bot_open "$T/$f/body.md")" = 4/4 ] && [ "$(bot_open "$T/$f/written.md")" = 0/4 ]'
  done
  # Both bots carry the parser; a body saved in the web UI has CRLF line ends.
  for wf in dor-dod-enforcement auto-promote-ready; do
    for header in "Definition of Done" "Definition of Ready"; do
      { sed -n '/function extractSection/,/^            }/p' "$AIKIT/workflow/context/templates/github/workflows/$wf.yml"
        echo 'const b = extractSection("## " + process.argv[2] + " (x)\r\n\r\n- [ ] A\r\n- [x] B\r\n\r\n## Next\r\n- [ ] C\r\n", process.argv[2]); console.log(b.filter(x => !x.checked).map(x => x.text).join() + "/" + b.length)'
      } > "$T/crlf.js"
      BOT_CRLF="$(node "$T/crlf.js" "$header")"
      assert "$wf: reads $header boxes in a CRLF body" '[ "$BOT_CRLF" = "A/2" ]'
    done
  done
else
  echo "  SKIP: node not found"
fi

command rm -rf "$T"
print_summary_and_exit
