#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== skills-count ==="
# section: skills-count
SKILL_COUNT=$(find "$AIKIT/workflow/skills" -name SKILL.md | wc -l | tr -d ' ')
assert "35 skills" '[ "$SKILL_COUNT" -eq 35 ]'
assert "plugin payload carries the changelog" '[ -f "$AIKIT/workflow/CHANGELOG.md" ]'
assert "checkpoint skill exists" '[ -f "$AIKIT/workflow/skills/checkpoint/SKILL.md" ]'
assert "resume skill exists" '[ -f "$AIKIT/workflow/skills/resume/SKILL.md" ]'
assert "rename-housekeeping skill exists" '[ -f "$AIKIT/workflow/skills/rename-housekeeping/SKILL.md" ]'


echo "=== agents ==="
# section: agents
AGENT_COUNT=$(find "$AIKIT/workflow/agents" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
assert "7 subagents present" '[ "$AGENT_COUNT" -eq 7 ]'
assert "explore exists" '[ -f "$AIKIT/workflow/agents/explore.md" ]'
assert "reviewer exists" '[ -f "$AIKIT/workflow/agents/reviewer.md" ]'
assert "qa-runner exists" '[ -f "$AIKIT/workflow/agents/qa-runner.md" ]'
assert "verifier exists" '[ -f "$AIKIT/workflow/agents/verifier.md" ]'
assert "builder exists" '[ -f "$AIKIT/workflow/agents/builder.md" ]'
assert "designer exists" '[ -f "$AIKIT/workflow/agents/designer.md" ]'
assert "judge exists" '[ -f "$AIKIT/workflow/agents/judge.md" ]'
assert "explore frontmatter name" 'head -5 "$AIKIT/workflow/agents/explore.md" | grep -q "^name: explore$"'
assert "explore frontmatter tools" 'head -5 "$AIKIT/workflow/agents/explore.md" | grep -q "^tools:"'
assert "reviewer frontmatter name" 'head -5 "$AIKIT/workflow/agents/reviewer.md" | grep -q "^name: reviewer$"'
assert "reviewer frontmatter pins opus" 'head -5 "$AIKIT/workflow/agents/reviewer.md" | grep -qx "model: opus"'
assert "qa-runner frontmatter name" 'head -5 "$AIKIT/workflow/agents/qa-runner.md" | grep -q "^name: qa-runner$"'
assert "qa-runner frontmatter tools" 'head -5 "$AIKIT/workflow/agents/qa-runner.md" | grep -q "^tools:"'
assert "qa-runner frontmatter has no model pin" '! head -5 "$AIKIT/workflow/agents/qa-runner.md" | grep -q "^model:"'
assert "verifier frontmatter name" 'head -5 "$AIKIT/workflow/agents/verifier.md" | grep -q "^name: verifier$"'
assert "verifier frontmatter pins opus" 'head -5 "$AIKIT/workflow/agents/verifier.md" | grep -qx "model: opus"'
assert "builder frontmatter name" 'head -5 "$AIKIT/workflow/agents/builder.md" | grep -q "^name: builder$"'
assert "builder frontmatter tools" 'head -5 "$AIKIT/workflow/agents/builder.md" | grep -q "^tools:"'
assert "builder frontmatter pins opus" 'head -5 "$AIKIT/workflow/agents/builder.md" | grep -qx "model: opus"'
assert "designer frontmatter name" 'head -5 "$AIKIT/workflow/agents/designer.md" | grep -q "^name: designer$"'
assert "designer frontmatter pins opus" 'head -5 "$AIKIT/workflow/agents/designer.md" | grep -qx "model: opus"'
# No tools: line on purpose — designer inherits the Paper MCP tools when the host has them.
assert "designer frontmatter has no tools list" '! head -5 "$AIKIT/workflow/agents/designer.md" | grep -q "^tools:"'
assert "judge frontmatter name" 'head -5 "$AIKIT/workflow/agents/judge.md" | grep -q "^name: judge$"'
assert "judge frontmatter pins opus" 'head -5 "$AIKIT/workflow/agents/judge.md" | grep -qx "model: opus"'
assert "judge frontmatter is read-only" 'head -5 "$AIKIT/workflow/agents/judge.md" | grep -qx "tools: Read, Grep, Glob, Bash"'


echo "=== slash-commands ==="
# section: slash-commands
COMMAND_COUNT=$(find "$AIKIT/workflow/commands" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
assert "11 slash commands present" '[ "$COMMAND_COUNT" -eq 11 ]'
for cmd in doctor which status no-globals upgrade next dedupe phase; do
  assert "$cmd command exists"     "[ -f \"$AIKIT/workflow/commands/$cmd.md\" ]"
  assert "$cmd has description"    "head -6 \"$AIKIT/workflow/commands/$cmd.md\" | grep -q '^description:'"
  assert "$cmd has allowed-tools"  "head -6 \"$AIKIT/workflow/commands/$cmd.md\" | grep -q '^allowed-tools:'"
done


echo "=== review-skill-delegation ==="
# section: review-skill-delegation
assert "review skill mentions reviewer" 'grep -q "reviewer" "$AIKIT/workflow/skills/review/SKILL.md"'
assert "review skill mentions inline fallback" 'grep -q "Cursor / hosts without subagents" "$AIKIT/workflow/skills/review/SKILL.md"'
# The migrated skills (#3) each carry a Run mode block + name their subagent.
for s in qa diagnose to-issues; do
  assert "$s skill has a Run mode block" 'grep -q "^## Run mode" "$AIKIT/workflow/skills/'"$s"'/SKILL.md"'
done
assert "qa skill delegates to qa-runner" 'grep -q "qa-runner" "$AIKIT/workflow/skills/qa/SKILL.md"'
assert "review skill spawns verifier" 'grep -q "subagent_type=ai:verifier" "$AIKIT/workflow/skills/review/SKILL.md"'
assert "autonomous skill spawns verifier" 'grep -q "subagent_type=ai:verifier" "$AIKIT/workflow/skills/autonomous/SKILL.md"'
assert "autonomous stop conditions list verify-refuted" 'grep -q "exit-gate verify-refuted" "$AIKIT/workflow/skills/autonomous/SKILL.md"'
assert "diagnose skill delegates to explore" 'grep -q "explore" "$AIKIT/workflow/skills/diagnose/SKILL.md"'
assert "to-issues skill delegates to explore" 'grep -q "explore" "$AIKIT/workflow/skills/to-issues/SKILL.md"'
assert "tdd skill has a Run mode block" 'grep -q "^## Run mode" "$AIKIT/workflow/skills/tdd/SKILL.md"'
assert "tdd skill delegates to builder" 'grep -q "subagent_type=ai:builder" "$AIKIT/workflow/skills/tdd/SKILL.md"'
assert "autonomous skill names builder as the per-issue worker" 'grep -q "subagent_type=ai:builder" "$AIKIT/workflow/skills/autonomous/SKILL.md"'
assert "design-to-code skill has a Run mode block" 'grep -q "^## Run mode" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skill delegates to designer" 'grep -q "subagent_type=ai:designer" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skill delegates to verifier" 'grep -q "subagent_type=ai:verifier" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skill delegates scoring to judge" 'grep -q "subagent_type=ai:judge" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skill caps fix rounds at 2" 'grep -q "round 2 of 2" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
for item in "Render vs reference" "Layout" "Breakpoints" "Theme" "No overflow"; do
  assert "design-to-code checklist has render item: $item" "grep -q \"\\*\\*$item\\*\\*\" \"\$AIKIT/workflow/skills/design-to-code/SKILL.md\""
done
for item in "text" "tokens" "no hardcoded values" "icons and states"; do
  assert "design-to-code checklist has code item: $item" "grep -q \"\\*\\*$item\\*\\*\" \"\$AIKIT/workflow/skills/design-to-code/SKILL.md\""
done
assert "design-to-code ends every run with AskUserQuestion" 'grep -q "AskUserQuestion" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge gives no partial credit" 'grep -q "No partial credit" "$AIKIT/workflow/agents/judge.md"'
assert "judge scores the lowest component" 'grep -q "lowest component" "$AIKIT/workflow/agents/judge.md"'
assert "judge stops at the round cap" 'grep -qF "STOP (cap reached, ask user)" "$AIKIT/workflow/agents/judge.md"'
assert "judge stops at round 2 or later" 'grep -qF "round 2 or later" "$AIKIT/workflow/agents/judge.md"'
assert "design-pin.sh pins untracked files" 'grep -q "git ls-files -o" "$AIKIT/workflow/bin/design-pin.sh"'
assert "design-to-code checklist has UX item: Clicks" 'grep -q "\*\*Clicks\*\*" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge and design-to-code support image reference mode" 'grep -q "\`image\`" "$AIKIT/workflow/agents/judge.md" && grep -q "\`image\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code names the overlay file" 'grep -q "\.agents/design-to-code\.overlay\.json" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
for key in bar tolerance breakpoints themes undesigned_states tasks units; do
  assert "design-to-code overlay lists key: $key" "grep -qF '\"$key\":' \"\$AIKIT/workflow/skills/design-to-code/SKILL.md\""
done
assert "missing overlay key fails as not configured" 'grep -q "not configured" "$AIKIT/workflow/agents/judge.md" && grep -q "not configured" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code requires a list_resources call to succeed" 'grep -q "\`list_resources\` call succeeds" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "default bar is 100 in judge and design-to-code" 'grep -q "default 100" "$AIKIT/workflow/agents/judge.md" && grep -q "every component ≥ 100" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge stops on a pin error without using a round" 'grep -q "no round used" "$AIKIT/workflow/agents/judge.md"'
assert "design-to-code guards against a self-referencing reference" 'grep -q "never under the unit.s \`paths\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code names the only does-not-apply cases" 'grep -qF "Empty \`undesigned_states\` means every state must be present; empty \`mask\`, \`visual.anchored\` or \`layout_exclude\` means nothing is masked, skipped or excluded. Only \`themes\` with one entry, and no task naming this unit, mean does not apply. Any other empty value is FAIL not configured." "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code fixes the Clicks evidence line format" 'grep -qF "<n>. click <selector> → <url>" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge and design-to-code accept an approved snapshot" 'grep -q "approved_at" "$AIKIT/workflow/agents/judge.md" && grep -q "approved_at" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skips Render vs reference when unchanged since approval" 'grep -q "unchanged since approval" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge checks the approved commit exists" 'grep -qF "git cat-file -e <approved_at>^{commit}" "$AIKIT/workflow/agents/judge.md"'
assert "design-to-code overlay tasks name their unit" 'grep -qF '"'"'"unit":'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code counts the mouse-only click path" 'grep -q "mouse-only path" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code overlay units can mask volatile fields" 'grep -qF '"'"'"mask": []'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -q "CSS selectors" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code pins unmasked reference files" 'grep -q "unmasked" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "approved-snapshot diff sees the working tree" '! grep -qF "<approved_at> HEAD" "$AIKIT/workflow/agents/judge.md" && ! grep -qF "<approved_at> HEAD" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "git diff <approved_at> -- <paths>" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code template has no empty approved_at" '! grep -qF '"'"'"approved_at": ""'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Clicks does not apply when no task names the unit" 'grep -qF "No task names this unit: Clicks does not apply" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "select(.unit==" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "only the user's accept sets approval, references or masks" 'grep -qF "Only the user'"'"'s accept in the closing \`AskUserQuestion\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qi "only the user.s accept" "$AIKIT/workflow/agents/judge.md"'
assert "undesigned_states is a closed list" 'grep -qF "\`hover\`, \`focus\`, \`active\`, \`loading\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF '"'"'["hover", "focus"]'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "multi-image sha runs from the repo root" 'grep -q "run from the repo root" "$AIKIT/workflow/agents/judge.md" && grep -q "run from the repo root" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-pin.sh pins the overlay without stored pins" 'grep -qF "jq -S '"'"'del(.units[].pin)'"'"'" "$AIKIT/workflow/bin/design-pin.sh"'
assert "Visual hierarchy b defines form controls" 'grep -qF "Buttons and links are not form controls" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "\`spinbutton\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "Measure popups and portals closed" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy b needs a named group" 'grep -qF "A group with no name is FAIL" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "spacing scale counts as a token only up to scale_max" 'grep -qF "only up to step 24 (6rem)" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF '"'"'"scale_max": 24'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "\`approved_at\`, \`mask\`, \`visual.anchored\`, \`layout_exclude\`, \`scale_max\` and \`visual.group_min_controls\` are optional; no item needs them" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge and design-to-code call design-pin.sh with measure.json" 'grep -qF "design-pin.sh\" <unit-id> <measure.json>" "$AIKIT/workflow/agents/judge.md" && grep -qF "design-pin.sh\" <unit-id> <measure.json>" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge Pin template is the design-pin.sh line verbatim" 'grep -qF "<the design-pin.sh line, verbatim>" "$AIKIT/workflow/agents/judge.md"'
assert "paper mode adds no frame id outside the pin line" '! grep -qF "frame id goes with it" "$AIKIT/workflow/agents/judge.md" && ! grep -qF "frame id goes with it" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "pin hashing is documented only in design-pin.sh" '! grep -qF "It hashes" "$AIKIT/workflow/agents/judge.md" && ! grep -qF "It hashes" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "measure.json schema lives once, in design-to-code" 'grep -qF '"'"'"group": "<nearest visual.group selector or null>"'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && ! grep -qF '"'"'"box":'"'"' "$AIKIT/workflow/agents/judge.md"'
assert "measure.json producer is named once" '! grep -qF "produced by the lead, produced by the lead" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && ! grep -qF "The lead produces \`measure.json\`, produced by the lead" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Layout fails a reference node missing from measure.json" 'grep -qF "no entry in \`measure.json\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy a counts visible matches" 'grep -qF "at most 1 entry of \`visual.primary\` with \`visible: true\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && ! grep -qF "(\`box.w\` and \`box.h\` > 0)" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy c defines numeric" 'grep -qF '"'"'^[-+]?[€$]?\s?[\d.,]+\s?%?$'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy d defines a row" 'grep -qF "vertical box ranges overlap" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy e measures visual.block gaps" 'grep -qF '"'"'"block":'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "x ranges overlap" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge and design-to-code leave an unreferenced redesign open" 'grep -qF "render open: user decides" "$AIKIT/workflow/agents/judge.md" && grep -qF "render open: user decides" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "measure.json schema stores non-length values" 'grep -qF '"'"'"value": "<computed string>"'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy b leaves popover-only groups out of scope" 'grep -qF "only inside an open popover or portal are out of scope" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code ties render open to mode open" 'grep -qF '"'"'"mode": "open"'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge scores Render vs reference OPEN in open mode" 'grep -qF "Each item is PASS or FAIL, except Render vs reference when \`reference.mode\` is \`open\`: OPEN, left out of the total." "$AIKIT/workflow/agents/judge.md" && grep -qF "| PASS / FAIL / OPEN |" "$AIKIT/workflow/agents/judge.md"'
assert "only the user sets mode open" 'grep -qF "sets \`mode: \"open\"\`, \`approved_at\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "sets \`mode: \"open\"\`, \`approved_at\`" "$AIKIT/workflow/agents/judge.md"'
assert "Text in open mode checks static copy keys" 'grep -qF "In open mode Text checks that every static copy key has its literal in source or locale." "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "measure.json stores a non-length length as value" 'grep -qF "a length property whose computed value is not a length (for example \`line-height: normal\`) uses \`value\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "group minimum is the overlay key group_min_controls" 'grep -qF '"'"'"group_min_controls": 2'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "holds \`visual.group_min_controls\` (default 2) or more form controls" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "a missing optional key means none or its default" 'grep -qF "A missing optional key means none (\`mask\`, \`visual.anchored\`, \`layout_exclude\`, \`approved_at\`) or its default (\`scale_max\`, \`visual.group_min_controls\`)." "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "a missing required visual key fails its sub-check" 'grep -qF "A missing required \`visual\` key (\`primary\`, \`group\`, \`block\`, \`max_gap_px\`) fails that sub-check as not configured." "$AIKIT/workflow/skills/design-to-code/SKILL.md" && ! grep -qF "any other missing \`visual\` key" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "sub-check e skips the gap above a user-anchored block" 'grep -qF '"'"'"anchored": []'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "skips the gap between a match of \`visual.anchored\`, which must also match \`visual.block\`, and the nearest block above it whose x range overlaps" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "a \`mask\`, \`visual.anchored\` or \`layout_exclude\` entry" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "a \`mask\`, \`visual.anchored\` or \`layout_exclude\` entry" "$AIKIT/workflow/agents/judge.md"'
assert "measure.json covers visual.anchored" 'grep -qF "\`visual.block\`, \`visual.anchored\`, and every node the reference measures" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "measure.json records a fixed property set" 'grep -qF "margin-top, margin-right, margin-bottom, margin-left, padding-top, padding-right, padding-bottom, padding-left, row-gap, column-gap, border-top-left-radius, border-top-right-radius, border-bottom-right-radius, border-bottom-left-radius, font-size, line-height (lengths); color, background-color, font-weight, text-align (values); and \`box\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "Layout checks only this fixed set." "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Layout never checks width and height" 'grep -qF "Width and height are layout results, not authored values: Layout never checks them, and only Visual hierarchy reads \`box\`." "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "layout_exclude is a user-only optional key in the example" 'grep -qF '"'"'"layout_exclude": []'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "Layout skips entries with \`excluded: true\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "exclusion too wide" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "match count" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Visual hierarchy b counts only visible controls" 'grep -qF "only controls with \`visible: true\` count toward \`visual.group_min_controls\`" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "hidden but focusable" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "measure.json entries carry visible and excluded flags" 'grep -qF '"'"'"visible": <bool>, "excluded": <bool>'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF "the judge reads only these flags, never the DOM" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-pin.sh exists and is executable" '[ -x "$AIKIT/workflow/bin/design-pin.sh" ]'
assert "judge and design-to-code compute the pin with design-pin.sh" 'grep -q "design-pin.sh" "$AIKIT/workflow/agents/judge.md" && grep -q "design-pin.sh" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "judge Bash scope names design-pin.sh" 'grep -q "^- \*\*Read-only.\*\*.*design-pin.sh" "$AIKIT/workflow/agents/judge.md"'
assert "judge and design-to-code take measured values from measure.json" 'grep -q "measure.json" "$AIKIT/workflow/agents/judge.md" && grep -q "measure.json" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF '"'"'"box":'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "approval never exempts Layout" 'grep -q "never Layout" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "no hardcoded values fails an arbitrary value on the scale" 'grep -q "arbitrary value that equals a scale step" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Text counts a runtime-built string by its render" 'grep -q "runtime-built string" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "Clicks max comes from the real path" 'grep -qF "Set \`max\` from the real path" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code checklist has Visual hierarchy" 'grep -q "\*\*Visual hierarchy\*\*" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -qF '"'"'"visual":'"'"' "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
for sub in "One primary action" "every form control sits inside a" "right-aligned" "Label baseline" "max_gap_px"; do
  assert "Visual hierarchy sub-check: $sub" "grep -qF \"$sub\" \"\$AIKIT/workflow/skills/design-to-code/SKILL.md\""
done
assert "design-to-code skill has a store flow with its fallback" 'grep -q "^### store" "$AIKIT/workflow/skills/design-to-code/SKILL.md" && grep -q "app-store-screenshots" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code skill has a Paper rules section" 'grep -q "^## Paper rules" "$AIKIT/workflow/skills/design-to-code/SKILL.md"'
assert "design-to-code, designer and judge carry no Pencil text" '! grep -rqiE "pencil|\.pen\b" "$AIKIT/workflow/skills/design-to-code" "$AIKIT/workflow/agents/designer.md" "$AIKIT/workflow/agents/judge.md"'


echo "=== plugin-manifest ==="
# section: plugin-manifest
PLUGIN_JSON="$AIKIT/workflow/.claude-plugin/plugin.json"
assert "plugin.json exists" '[ -f "$PLUGIN_JSON" ]'
assert "plugin.json is valid JSON" 'python3 -c "import json; json.load(open(\"$PLUGIN_JSON\"))"'
assert "plugin.json name is ai" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d[\"name\"]==\"ai\""'
assert "plugin.json has description" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d.get(\"description\")"'
assert "plugin.json has version" 'python3 -c "import json; d=json.load(open(\"$PLUGIN_JSON\")); assert d.get(\"version\")"'

# The marketplace catalog moved to the standalone yusufkaracaburun/marketplace
# repo on 2026-05-23 (closes #9). The in-repo `.claude-plugin/marketplace.json`
# must NOT come back — its presence would resurrect the legacy install path.
assert "in-repo marketplace.json is removed" '[ ! -f "$AIKIT/.claude-plugin/marketplace.json" ]'
assert "no .claude-plugin/ directory at repo root" '[ ! -d "$AIKIT/.claude-plugin" ]'

# plugin.json:version equals VERSION.
assert "VERSION/plugin.json version equality" \
  'bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1'


echo "=== sync-plugin-version-drift ==="
# section: sync-plugin-version-drift
# sync-plugin-version.sh stamps drift away.
#
# Against a throwaway root, never the repo. This block used to write
# `0.0.0-drift` into the real workflow/.claude-plugin/plugin.json and restore
# it three commands later, while run-all.sh dispatches cases four at a time.
# Any case invoking ai-kit-doctor.sh inside that window saw the corrupted
# manifest, got a warning, and exited 1 — which is the whole of #134. It read
# as an environment quirk because the window is milliseconds wide, it never
# reproduced when doctor was run on its own, and it landed on a different
# assertion each time depending on which doctor call happened to fall inside
# it. Shared mutable state in a parallel suite, not a platform divergence.
#
# resolve_ai_kit_root honours AI_KIT_ROOT ahead of script location, so a root
# holding just VERSION and the manifest is enough. No change to
# sync-plugin-version.sh, and no serialising the suite to make one test safe.
TMP_PLUGIN_ROOT=$(mktemp -d)
mkdir -p "$TMP_PLUGIN_ROOT/workflow/.claude-plugin"
cp "$AIKIT/VERSION" "$TMP_PLUGIN_ROOT/VERSION"
cp "$PLUGIN_JSON" "$TMP_PLUGIN_ROOT/workflow/.claude-plugin/plugin.json"

python3 -c "
import json
p='$TMP_PLUGIN_ROOT/workflow/.claude-plugin/plugin.json'
d=json.load(open(p))
d['version']='0.0.0-drift'
json.dump(d, open(p,'w'), indent=2)
open(p,'a').write('\n')
"
set +e
AI_KIT_ROOT="$TMP_PLUGIN_ROOT" bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1
SYNC_DRIFT_EXIT=$?
set -e
assert "sync-plugin-version --check detects drift" '[ "$SYNC_DRIFT_EXIT" -eq 1 ]'
AI_KIT_ROOT="$TMP_PLUGIN_ROOT" bash "$AIKIT/bin/sync-plugin-version.sh" >/dev/null
set +e
AI_KIT_ROOT="$TMP_PLUGIN_ROOT" bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1
SYNC_STAMP_EXIT=$?
set -e
assert "sync-plugin-version stamps drift away" '[ "$SYNC_STAMP_EXIT" -eq 0 ]'

# The repo's own manifest must be untouched throughout — that is the property
# the parallel suite depends on.
assert "the repo manifest was never mutated" \
  'bash "$AIKIT/bin/sync-plugin-version.sh" --check >/dev/null 2>&1'
rm -rf "$TMP_PLUGIN_ROOT"


echo "=== sync-plugin-hooks-bundled-hook-scripts- ==="
# section: sync-plugin-hooks-bundled-hook-scripts-
BUNDLED_POST="$AIKIT/workflow/hooks/post-skill-log.sh"
BUNDLED_LOG="$AIKIT/workflow/hooks/log-skill.sh"
BUNDLED_JSON="$AIKIT/workflow/hooks/hooks.json"
assert "bundled post-skill-log.sh exists + executable" '[ -x "$BUNDLED_POST" ]'
assert "bundled log-skill.sh exists + executable" '[ -x "$BUNDLED_LOG" ]'
assert "bundled hooks.json exists" '[ -f "$BUNDLED_JSON" ]'
assert "hooks.json is valid JSON" 'python3 -c "import json; json.load(open(\"$BUNDLED_JSON\"))"'
assert "hooks.json has PostToolUse Skill matcher" 'python3 -c "
import json
d=json.load(open(\"$BUNDLED_JSON\"))
e=d[\"hooks\"][\"PostToolUse\"][0]
assert e[\"matcher\"]==\"^Skill\$\"
assert e[\"hooks\"][0][\"command\"]==\"\${CLAUDE_PLUGIN_ROOT}/hooks/post-skill-log.sh\"
"'
assert "bundled hook byte-identical to bin/ source" 'cmp -s "$AIKIT/bin/hooks/post-skill-log.sh" "$BUNDLED_POST"'
assert "bundled log-skill byte-identical to bin/ source" 'cmp -s "$AIKIT/bin/log-skill.sh" "$BUNDLED_LOG"'
assert "sync-plugin-hooks --check clean" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'

# apply-sandcastle.sh overwrites the copied main.mts with main.ts.template, so
# the template is what users actually run. Re-vendoring one and not the other
# ships two different scaffolds; the manifest says so in prose, this enforces it.
assert "sandcastle main.ts.template byte-identical to main.mts" \
  'cmp -s "$AIKIT/orchestration/sandcastle/main.ts.template" "$AIKIT/orchestration/sandcastle/sequential-reviewer/main.mts"' 

# The --check family only catches drift in a mirror that EXISTS. workflow/
# had no orchestration/ at all for five releases, so nothing drifted and
# nothing complained — apply-sandcastle.sh just left an empty .sandcastle/
# and /ai:setup branch 8 reported success. The durable guard is behavioural:
# run the plugin-side script and require it to actually produce the scaffold.
TMP_SC=$(mktemp -d)
printf '{"name":"t"}' > "$TMP_SC/package.json"
bash "$AIKIT/workflow/bin/apply-sandcastle.sh" "$TMP_SC" >/dev/null 2>&1 || true
SC_FILES=$(find "$TMP_SC/.sandcastle" -type f 2>/dev/null | wc -l | tr -d ' ')
assert "plugin-side apply-sandcastle produces a non-empty scaffold" '[ "$SC_FILES" -ge 5 ]'
assert "plugin-side scaffold leaves no unresolved placeholders" \
  '! grep -rq "{{INSTALL_CMD}}\|{{COPY_TO_WORKTREE}}" "$TMP_SC/.sandcastle" 2>/dev/null'
rm -rf "$TMP_SC"
assert "workflow/context/templates/github exists in plugin" '[ -d "$AIKIT/workflow/context/templates/github" ]'
assert "workflow/bin/ai-kit-doctor.sh exists" '[ -x "$AIKIT/workflow/bin/ai-kit-doctor.sh" ]'
assert "plugin commands use CLAUDE_PLUGIN_ROOT" '! grep -lE "AI_KIT_ROOT.*\\\$HOME/\\.config/ai-kit/root.*}/bin/" "$AIKIT/workflow/commands/"*.md'

# Drift detection round-trip: mutate, --check fails, re-stamp, --check passes.
TMP_HOOK_BAK=$(mktemp -d)
cp "$BUNDLED_POST" "$TMP_HOOK_BAK/post-skill-log.sh"
echo "# tampered" >> "$BUNDLED_POST"
set +e
bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1
HOOK_DRIFT_EXIT=$?
set -e
assert "sync-plugin-hooks --check detects drift" '[ "$HOOK_DRIFT_EXIT" -eq 1 ]'
bash "$AIKIT/bin/sync-plugin-hooks.sh" >/dev/null
assert "sync-plugin-hooks stamps drift away" 'bash "$AIKIT/bin/sync-plugin-hooks.sh" --check >/dev/null 2>&1'
rm -rf "$TMP_HOOK_BAK"


echo "=== VERSION ==="
# section: VERSION
assert "VERSION file" '[ -f "$AIKIT/VERSION" ]'


echo "=== eval-golden ==="
# section: eval-golden
# Each golden must satisfy its own rubric — catches drift where you weaken
# either the rubric or the golden without keeping them in sync.
if "$AIKIT/bin/eval-golden.sh" --validate-all > /tmp/eval-golden.out 2>&1; then
  GOLDEN_OK=true
else
  GOLDEN_OK=false
  echo "  (eval-golden.sh failures — see /tmp/eval-golden.out)"
  tail -20 /tmp/eval-golden.out
fi
assert "all goldens satisfy own rubric" '[ "$GOLDEN_OK" = true ]'

# A deliberately bad response must FAIL several checks — sanity for the
# rubric runner itself (catches the runner silently passing everything).
TMP_BAD_RESP=$(mktemp)
cat > "$TMP_BAD_RESP" <<'BADRESP'
---
id: cart-checkout
---

# Trivial response, hits none of the structural checks.

Some words here.
BADRESP
set +e
"$AIKIT/bin/eval-golden.sh" tdd cart-checkout "$TMP_BAD_RESP" > /tmp/eval-golden-bad.out 2>&1
BAD_EXIT=$?
set -e
assert "bad response fails (exit 1)" '[ "$BAD_EXIT" -eq 1 ]'
assert "bad response reports failed checks" 'grep -q "FAIL" /tmp/eval-golden-bad.out'
rm -f "$TMP_BAD_RESP"

# Coverage: each priority skill (to-prd, tdd) has a golden.
for prio in to-prd tdd; do
  assert "golden exists: $prio" '[ -f "$AIKIT/tests/eval/goldens/$prio"/*.md ] || ls "$AIKIT/tests/eval/goldens/$prio"/*.md >/dev/null 2>&1'
done


echo "=== eval-structure ==="
# section: eval-structure
if "$AIKIT/tests/bin/eval-structure.sh" > /tmp/eval-structure.out 2>&1; then
  STRUCT_OK=true
else
  STRUCT_OK=false
  echo "  (eval-structure.sh failures — see /tmp/eval-structure.out)"
  tail -20 /tmp/eval-structure.out
fi
assert "eval-structure clean" '[ "$STRUCT_OK" = true ]'


print_summary_and_exit
