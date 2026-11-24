#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== bin-autonomous-queue-sh ==="
# section: bin-autonomous-queue-sh
TMP_AQ=$(mktemp -d)
mkdir -p "$TMP_AQ/stubs"

# Stub 1: empty queue.
cat > "$TMP_AQ/stubs/gh" <<'STUB'
#!/usr/bin/env bash
echo "[]"
STUB
chmod +x "$TMP_AQ/stubs/gh"

AQ_OUT_EMPTY="$(PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next)"
assert "empty queue: empty stdout" '[ -z "$AQ_OUT_EMPTY" ]'

AQ_JSON_EMPTY="$(PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next --json)"
assert "empty queue --json: null" '[ "$AQ_JSON_EMPTY" = "null" ]'

# Stub 2: populated queue. Oldest by updatedAt should win.
cat > "$TMP_AQ/stubs/gh" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
[
  {"number": 42, "title": "newer one", "updatedAt": "2026-05-22T10:00:00Z"},
  {"number": 18, "title": "older one", "updatedAt": "2026-05-20T10:00:00Z"}
]
JSON
STUB

AQ_OUT_POP="$(PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next)"
assert "populated picks oldest plain" '[ "$AQ_OUT_POP" = "$(printf "18\tolder one")" ]'

AQ_JSON_POP="$(PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next --json)"
assert "populated --json includes issue #" 'echo "$AQ_JSON_POP" | grep -q "\"issue\": 18"'
assert "populated --json includes title"   'echo "$AQ_JSON_POP" | grep -q "\"title\": \"older one\""'

# An issue that already has an open PR is skipped, and the skip is logged.
cat > "$TMP_AQ/stubs/gh" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = pr ]; then
  echo "$*" > "$GH_PR_ARGS_LOG"
  echo '[{"number": 101, "closingIssuesReferences": [{"number": 18}]}]'
else
  echo '[{"number": 42, "title": "newer one", "updatedAt": "2026-05-22T10:00:00Z"},
         {"number": 18, "title": "older one", "updatedAt": "2026-05-20T10:00:00Z"}]'
fi
STUB
AQ_OUT_PR="$(GH_PR_ARGS_LOG="$TMP_AQ/pr.args" PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next --log "$TMP_AQ/progress.txt" 2>"$TMP_AQ/skip.err")"
assert "open PR: skips the issue with an open PR" '[ "$AQ_OUT_PR" = "$(printf "42\tnewer one")" ]'
assert "open PR: --log gets the skip line in progress.txt schema" \
  'grep -qE "^[0-9TZ:-]+	18	skip	open-pr=101$" "$TMP_AQ/progress.txt"'
assert "open PR: stderr stays free for errors" '[ ! -s "$TMP_AQ/skip.err" ]'
assert "open PR: pr list asks past the default page" 'grep -q -- "--limit 200" "$TMP_AQ/pr.args"'

# Label comes from docs/agents/triage-labels.md; ready-for-agent without it.
cat > "$TMP_AQ/stubs/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$GH_ARGS_LOG"
echo "[]"
STUB
mkdir -p "$TMP_AQ/repo/docs/agents"
(cd "$TMP_AQ/repo" && GH_ARGS_LOG="$TMP_AQ/args" PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next >/dev/null)
assert "no triage-labels.md: queries ready-for-agent" 'grep -q -- "--label ready-for-agent " "$TMP_AQ/args"'
sed 's/| `ready-for-agent`    | Fully/| `afk-ready`          | Fully/' \
  "$AIKIT/workflow/context/templates/docs/agents/triage-labels.md" > "$TMP_AQ/repo/docs/agents/triage-labels.md"
(cd "$TMP_AQ/repo" && GH_ARGS_LOG="$TMP_AQ/args" PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next >/dev/null)
assert "triage-labels.md maps the label: queries afk-ready" 'grep -q -- "--label afk-ready " "$TMP_AQ/args"'
sed 's/| `ready-for-agent`    | Fully/| `ready for agent`    | Fully/' \
  "$AIKIT/workflow/context/templates/docs/agents/triage-labels.md" > "$TMP_AQ/repo/docs/agents/triage-labels.md"
(cd "$TMP_AQ/repo" && GH_ARGS_LOG="$TMP_AQ/args" PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next >/dev/null)
assert "label with inner spaces keeps them" 'grep -q -- "--label ready for agent --state" "$TMP_AQ/args"'

# Stub 3: bad JSON from gh.
cat > "$TMP_AQ/stubs/gh" <<'STUB'
#!/usr/bin/env bash
echo "not-json"
STUB
AQ_BAD_RC=0
PATH="$TMP_AQ/stubs:$PATH" "$AIKIT/bin/autonomous-queue.sh" next >/dev/null 2>&1 || AQ_BAD_RC=$?
assert "bad JSON exits nonzero" '[ "$AQ_BAD_RC" -ne 0 ]'

# Missing gh: provide a PATH that excludes the gh-containing dir but still
# resolves system tools. On GitHub's ubuntu runner /bin is symlinked to
# /usr/bin (which carries gh), so we can't build a "no-gh" PATH that still
# resolves bash; skip the assertion when /bin/gh exists (it's a two-line
# `command -v gh` shell check we already trust).
mkdir -p "$TMP_AQ/stubs-empty"
if [ -e /bin/gh ] || [ -e /usr/bin/gh ] && [ "$(cd /bin 2>/dev/null && pwd -P)" = "$(cd /usr/bin 2>/dev/null && pwd -P)" ]; then
  echo "  SKIP: missing-gh test (system has /bin/gh — cannot isolate)"
else
  AQ_NO_GH_RC=0
  PATH="$TMP_AQ/stubs-empty:/usr/bin:/bin" "$AIKIT/bin/autonomous-queue.sh" next \
    >/dev/null 2>&1 || AQ_NO_GH_RC=$?
  assert "missing gh exits nonzero (3)" '[ "$AQ_NO_GH_RC" -eq 3 ]'
fi

# Bad subcommand or no args => usage on stderr, nonzero exit.
AQ_USAGE_RC=0
"$AIKIT/bin/autonomous-queue.sh" >/dev/null 2>&1 || AQ_USAGE_RC=$?
assert "no args exits nonzero" '[ "$AQ_USAGE_RC" -ne 0 ]'

AQ_BAD_ARG_RC=0
"$AIKIT/bin/autonomous-queue.sh" --bogus >/dev/null 2>&1 || AQ_BAD_ARG_RC=$?
assert "bad arg exits nonzero" '[ "$AQ_BAD_ARG_RC" -ne 0 ]'

rm -rf "$TMP_AQ"


echo "=== setup-gh-workflow ==="
# section: setup-gh-workflow
GH_SETUP="$AIKIT/bin/setup-gh-workflow.sh"
assert "setup-gh-workflow is executable" '[ -x "$GH_SETUP" ]'

# Silent skip on non-GitHub remote (or no remote at all).
TMP_GH_NONE=$(mktemp -d)
(cd "$TMP_GH_NONE" && git init -q && git remote add origin https://gitlab.com/foo/bar.git)
OUT_GH_NONE="$("$GH_SETUP" "$TMP_GH_NONE" --no-labels --no-project --quiet 2>&1 || true)"
assert "non-GitHub remote: no templates written" '[ ! -d "$TMP_GH_NONE/.github" ]'
rm -rf "$TMP_GH_NONE"

# Dutch default — templates land, workflows land, idempotent.
TMP_GH_NL=$(mktemp -d)
(cd "$TMP_GH_NL" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_NL" --no-labels --no-project --quiet >/dev/null
assert "nl: story template written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md" ]'
assert "nl: spike template written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/spike.md" ]'
assert "nl: config.yml written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/config.yml" ]'
assert "nl: dor-dod workflow written" '[ -f "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml" ]'
assert "nl: auto-promote workflow written" '[ -f "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml" ]'
assert "nl: gitleaks workflow written" '[ -f "$TMP_GH_NL/.github/workflows/gitleaks.yml" ]'
# End-to-end: the gate ai-kit-secrets-gate.sh enforces must be satisfied by
# what setup-gh-workflow.sh produces. Before this, the gate warned about a
# file no script wrote.
assert "secrets-gate passes on a freshly scaffolded repo" \
  '"$AIKIT/bin/ai-kit-secrets-gate.sh" "$TMP_GH_NL" >/dev/null 2>&1'
h2s() { sed -n 's/^## //p' "$1" | paste -sd '|' -; }
assert "nl: bug template carries the required H2s" '[ "$(h2s "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md")" = "Stappen|Verwacht|Werkelijk|Waar|Acceptance criteria|Definition of Done (vóór close)" ]'
assert "nl: bug template has a regression-test criterion" 'grep -q "^- \[ \] .*[Rr]egressietest" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md"'
assert "nl: epic template carries its H2s" '[ "$(h2s "$TMP_GH_NL/.github/ISSUE_TEMPLATE/epic.md")" = "Doel|Klaar wanneer|Buiten scope|Definition of Done (vóór close)" ]'
assert "nl: task template carries its H2s" '[ "$(h2s "$TMP_GH_NL/.github/ISSUE_TEMPLATE/task.md")" = "Wat|Acceptance criteria|Definition of Done (vóór close)" ]'
assert "no feature template is written" '[ ! -e "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md" ]'
assert "nl: idea template carries what, why, when" '[ "$(h2s "$TMP_GH_NL/.github/ISSUE_TEMPLATE/idea.md")" = "Wat|Waarom|Wanneer oppakken" ]'
assert "nl: story has Dutch DoR header" 'grep -q "Definition of Ready (vóór \"In Progress\")" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "nl: story has Triage section" 'grep -q "## Triage" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "nl: story has Depends on field" 'grep -q "Depends on:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "nl: story has Blocks field" 'grep -q "Blocks:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "nl: spike has Time-box field" 'grep -q "Time-box:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/spike.md"'

# Workflows carry the right anchors.
assert "dor-dod workflow parses DoR header" 'grep -q "Definition of Ready" "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml"'
assert "dor-dod workflow parses DoD header" 'grep -q "Definition of Done" "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml"'
assert "auto-promote checks P[0-3] labels" 'grep -q "P\\[0-3\\]-" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'
assert "auto-promote checks area/ labels" 'grep -q "area/" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'

# Placeholders remain when --no-project (script did not resolve them).
assert "auto-promote keeps PROJECT_NUMBER placeholder" 'grep -q "AI_KIT_PROJECT_NUMBER" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'

# Idempotency — second run does not overwrite. Mutate the file, re-run, check.
echo "USER_EDIT" >> "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"
echo "USER_EDIT" >> "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md"
echo "USER_EDIT" >> "$TMP_GH_NL/.github/ISSUE_TEMPLATE/idea.md"
"$GH_SETUP" "$TMP_GH_NL" --no-labels --no-project --quiet >/dev/null
assert "idempotent: user edits preserved on re-run" 'grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "idempotent: existing bug.md and idea.md preserved on re-run" 'grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md" && grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/idea.md"'

# --force overwrites.
"$GH_SETUP" "$TMP_GH_NL" --no-labels --no-project --quiet --force >/dev/null
assert "force: user edits cleared" '! grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/story.md"'
assert "force: bug.md and idea.md edits cleared" 'grep -q "^## Stappen" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md" && ! grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/bug.md" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/idea.md"'
rm -rf "$TMP_GH_NL"

# English variant.
TMP_GH_EN=$(mktemp -d)
(cd "$TMP_GH_EN" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_EN" --lang en --no-labels --no-project --quiet >/dev/null
assert "en: story has English DoR header" 'grep -q "Definition of Ready (before \"In Progress\")" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/story.md"'
assert "en: story has English Scope content" 'grep -q "Measurable criterion" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/story.md"'
assert "en: bug template carries the required H2s" '[ "$(h2s "$TMP_GH_EN/.github/ISSUE_TEMPLATE/bug.md")" = "Steps|Expected|Actual|Where|Acceptance criteria|Definition of Done (before close)" ]'
assert "en: bug template has a regression-test criterion" 'grep -q "^- \[ \] .*[Rr]egression test" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/bug.md"'
assert "en: epic template carries its H2s" '[ "$(h2s "$TMP_GH_EN/.github/ISSUE_TEMPLATE/epic.md")" = "Goal|Done when|Out of scope|Definition of Done (before close)" ]'
assert "en: task template carries its H2s" '[ "$(h2s "$TMP_GH_EN/.github/ISSUE_TEMPLATE/task.md")" = "What|Acceptance criteria|Definition of Done (before close)" ]'
assert "en: idea template carries what, why, when" '[ "$(h2s "$TMP_GH_EN/.github/ISSUE_TEMPLATE/idea.md")" = "What|Why|When to pick up" ]'
assert "en: spike has English Goal header" 'grep -q "## Goal" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/spike.md"'
rm -rf "$TMP_GH_EN"

# Priority is a project field, not body text; the Triage heading stays.
for f in story.md story.en.md spike.md spike.en.md; do
  # shellcheck disable=SC2034
  TRIAGE_SECTION="$(sed -n '/^## Triage$/,/^## /p' "$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/$f")"
  assert "$f: Triage heading present without a Priority line" '[ -n "$TRIAGE_SECTION" ] && ! grep -q "Priority" <<<"$TRIAGE_SECTION"'
done

# A built card closes on a Definition of Done the bot can parse; an idea card has none.
for lang in "" .en; do
  # shellcheck disable=SC2034
  IDEA="$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/idea$lang.md"
  assert "idea$lang.md: no DoR or DoD" '! grep -q "Definition of" "$IDEA"'
  for t in epic story task bug spike; do
    # shellcheck disable=SC2034
    DOD_BOXES="$(sed -n '/^## Definition of Done/,/^## /p' "$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/$t$lang.md" | grep -c '^- \[ \] ' || true)"
    assert "$t$lang.md: DoD has 3 to 5 checkboxes" '[ "$DOD_BOXES" -ge 3 ] && [ "$DOD_BOXES" -le 5 ]'
  done
done

# Every checkbox names its proof.
for f in "$AIKIT"/workflow/context/templates/github/ISSUE_TEMPLATE/*.md; do
  # shellcheck disable=SC2034
  UNPROVEN="$(grep '^- \[ \] ' "$f" | grep -vE '\((proof|bewijs): .+\)$' || true)"
  assert "$(basename "$f"): every checkbox names its proof" '[ -z "$UNPROVEN" ]'
done
# shellcheck disable=SC2034
STORY_DOR="$(sed -n '/^## Definition of Ready/,/^## /p' "$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/story.en.md")"
for w in Independent Small Testable; do
  assert "story DoR has the $w box" "grep -q '^- \[ \] $w: ' <<<\"\$STORY_DOR\""
done

for lang in "" .en; do
  for t in story spike; do
    assert "$t$lang.md: DoR accepts a card without an epic" "grep -qE '^- \[ \] Priority.*Epic(-label, of geen| label, or none)' '$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/$t$lang.md'"
  done
  assert "story$lang.md: Triage has an Estimate line and the Small box reads it" "sed -n '/^## Triage/,/^## Scope/p' '$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/story$lang.md' | grep -q '^- \*\*Estimate:\*\*' && grep -qE '^- \[ \] Small: .*(reason|reden)' '$AIKIT/workflow/context/templates/github/ISSUE_TEMPLATE/story$lang.md'"
done

# A repo that still has feature.md hears it once; the file stays.
TMP_GH_OLD=$(mktemp -d)
(cd "$TMP_GH_OLD" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git && mkdir -p .github/ISSUE_TEMPLATE && echo OLD > .github/ISSUE_TEMPLATE/feature.md)
# shellcheck disable=SC2034
OUT_OLD="$("$GH_SETUP" "$TMP_GH_OLD" --no-labels --no-project --no-protection)"
assert "feature.md found: one line, file kept" '[ "$(grep -c "feature.md found" <<<"$OUT_OLD")" -eq 1 ] && grep -qx OLD "$TMP_GH_OLD/.github/ISSUE_TEMPLATE/feature.md"'
rm -rf "$TMP_GH_OLD"

# Dry-run writes nothing.
TMP_GH_DRY=$(mktemp -d)
(cd "$TMP_GH_DRY" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_DRY" --no-labels --no-project --quiet --dry-run >/dev/null
assert "dry-run: no files written" '[ ! -f "$TMP_GH_DRY/.github/ISSUE_TEMPLATE/story.md" ]'
rm -rf "$TMP_GH_DRY"

# Workflows have the right top-level structure (name + on + jobs).
# Using grep rather than yaml.safe_load — pyyaml is not in stdlib and
# requiring it would block CI on minimal images. The full YAML is sourced
# verbatim from the portal app's production setup, so syntactic validity is
# established upstream; we only need to assert our copy preserved the
# load-bearing top-level keys.
TMP_GH_YAML=$(mktemp -d)
(cd "$TMP_GH_YAML" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_YAML" --no-labels --no-project --quiet >/dev/null
assert "dor-dod workflow has name + on + jobs" 'grep -q "^name:" "$TMP_GH_YAML/.github/workflows/dor-dod-enforcement.yml" && grep -q "^on:" "$TMP_GH_YAML/.github/workflows/dor-dod-enforcement.yml" && grep -q "^jobs:" "$TMP_GH_YAML/.github/workflows/dor-dod-enforcement.yml"'
assert "auto-promote workflow has name + on + jobs" 'grep -q "^name:" "$TMP_GH_YAML/.github/workflows/auto-promote-ready.yml" && grep -q "^on:" "$TMP_GH_YAML/.github/workflows/auto-promote-ready.yml" && grep -q "^jobs:" "$TMP_GH_YAML/.github/workflows/auto-promote-ready.yml"'
rm -rf "$TMP_GH_YAML"

# Bootstrap silent-skips gh-workflow on non-GitHub remote without breaking.
TMP_BS_GL=$(mktemp -d)
(cd "$TMP_BS_GL" && git init -q && git remote add origin https://gitlab.com/foo/bar.git)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-rules "$TMP_BS_GL" >/dev/null 2>&1 || true
assert "bootstrap on non-GitHub: no .github/ scaffolded" '[ ! -d "$TMP_BS_GL/.github" ]'
rm -rf "$TMP_BS_GL"

# Bootstrap on a GitHub remote DOES scaffold the workflow files.
TMP_BS_GH=$(mktemp -d)
(cd "$TMP_BS_GH" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-rules "$TMP_BS_GH" >/dev/null 2>&1
assert "bootstrap on GitHub: story template scaffolded" '[ -f "$TMP_BS_GH/.github/ISSUE_TEMPLATE/story.md" ]'
assert "bootstrap on GitHub: dor-dod workflow scaffolded" '[ -f "$TMP_BS_GH/.github/workflows/dor-dod-enforcement.yml" ]'
rm -rf "$TMP_BS_GH"

# --no-gh-workflow flag suppresses.
TMP_BS_NO=$(mktemp -d)
(cd "$TMP_BS_NO" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-rules --no-gh-workflow "$TMP_BS_NO" >/dev/null 2>&1
assert "bootstrap --no-gh-workflow: no .github/ scaffolded" '[ ! -d "$TMP_BS_NO/.github" ]'
rm -rf "$TMP_BS_NO"


echo "=== label-catalog contract ==="
# section: label-catalog-contract
# Every label the ai-kit tooling queries must exist in the catalog the setup
# script creates. Before this contract, autonomous-queue.sh filtered on
# `ready-for-agent` and ai-kit-next.sh scored the triage labels, while
# labels.json only shipped P0-P3 / epic / area / status:in-progress — so the
# AFK queue was permanently empty on a fresh install.
LABELS_JSON="$AIKIT/context/templates/github/labels.json"
assert "labels.json parses as JSON" 'python3 -c "import json;json.load(open(\"$LABELS_JSON\"))"'

CATALOG_NAMES="$(python3 -c "
import json
print(' '.join(l['name'] for l in json.load(open('$LABELS_JSON'))))
")"
for lbl in needs-triage needs-info ready-for-agent ready-for-human wontfix \
           P0-critical P1-high P2-medium P3-low status:in-progress; do
  assert "catalog ships label '$lbl'" 'echo " $CATALOG_NAMES " | grep -q " '"$lbl"' "'
done

assert "autonomous-queue falls back to a catalogued label" \
  'grep -qF "READY_LABEL:-ready-for-agent" "$AIKIT/bin/autonomous-queue.sh" && echo " $CATALOG_NAMES " | grep -q " ready-for-agent "'

# Every P-label in the catalog must satisfy the auto-promote regex /^P[0-3]-/,
# otherwise a correctly-labelled issue never promotes Todo -> Ready.
assert "catalog P-labels match the auto-promote regex" \
  'python3 -c "
import json, re, sys
ls=[l[\"name\"] for l in json.load(open(\"$LABELS_JSON\")) if l[\"name\"].startswith(\"P\")]
sys.exit(0 if ls and all(re.match(r\"^P[0-3]-\", n) for n in ls) else 1)
"'


print_summary_and_exit
