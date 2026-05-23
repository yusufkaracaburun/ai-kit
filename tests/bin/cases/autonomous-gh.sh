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
assert "nl: feature template written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md" ]'
assert "nl: spike template written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/spike.md" ]'
assert "nl: config.yml written" '[ -f "$TMP_GH_NL/.github/ISSUE_TEMPLATE/config.yml" ]'
assert "nl: dor-dod workflow written" '[ -f "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml" ]'
assert "nl: auto-promote workflow written" '[ -f "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml" ]'
assert "nl: feature has Dutch DoR header" 'grep -q "Definition of Ready (vóór \"In Progress\")" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'
assert "nl: feature has Triage section" 'grep -q "## Triage" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'
assert "nl: feature has Depends on field" 'grep -q "Depends on:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'
assert "nl: feature has Blocks field" 'grep -q "Blocks:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'
assert "nl: spike has Time-box field" 'grep -q "Time-box:" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/spike.md"'

# Workflows carry the right anchors.
assert "dor-dod workflow parses DoR header" 'grep -q "Definition of Ready" "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml"'
assert "dor-dod workflow parses DoD header" 'grep -q "Definition of Done" "$TMP_GH_NL/.github/workflows/dor-dod-enforcement.yml"'
assert "auto-promote checks P[0-3] labels" 'grep -q "P\\[0-3\\]-" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'
assert "auto-promote checks epic/ labels" 'grep -q "epic/" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'
assert "auto-promote checks area/ labels" 'grep -q "area/" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'

# Placeholders remain when --no-project (script did not resolve them).
assert "auto-promote keeps PROJECT_NUMBER placeholder" 'grep -q "AI_KIT_PROJECT_NUMBER" "$TMP_GH_NL/.github/workflows/auto-promote-ready.yml"'

# Idempotency — second run does not overwrite. Mutate the file, re-run, check.
echo "USER_EDIT" >> "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"
"$GH_SETUP" "$TMP_GH_NL" --no-labels --no-project --quiet >/dev/null
assert "idempotent: user edits preserved on re-run" 'grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'

# --force overwrites.
"$GH_SETUP" "$TMP_GH_NL" --no-labels --no-project --quiet --force >/dev/null
assert "force: user edits cleared" '! grep -q "USER_EDIT" "$TMP_GH_NL/.github/ISSUE_TEMPLATE/feature.md"'
rm -rf "$TMP_GH_NL"

# English variant.
TMP_GH_EN=$(mktemp -d)
(cd "$TMP_GH_EN" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_EN" --lang en --no-labels --no-project --quiet >/dev/null
assert "en: feature has English DoR header" 'grep -q "Definition of Ready (before \"In Progress\")" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/feature.md"'
assert "en: feature has English Scope content" 'grep -q "Measurable criterion" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/feature.md"'
assert "en: spike has English Goal header" 'grep -q "## Goal" "$TMP_GH_EN/.github/ISSUE_TEMPLATE/spike.md"'
rm -rf "$TMP_GH_EN"

# Dry-run writes nothing.
TMP_GH_DRY=$(mktemp -d)
(cd "$TMP_GH_DRY" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$GH_SETUP" "$TMP_GH_DRY" --no-labels --no-project --quiet --dry-run >/dev/null
assert "dry-run: no files written" '[ ! -f "$TMP_GH_DRY/.github/ISSUE_TEMPLATE/feature.md" ]'
rm -rf "$TMP_GH_DRY"

# Workflows have the right top-level structure (name + on + jobs).
# Using grep rather than yaml.safe_load — pyyaml is not in stdlib and
# requiring it would block CI on minimal images. The full YAML is sourced
# verbatim from naschool's production setup, so syntactic validity is
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
assert "bootstrap on GitHub: feature template scaffolded" '[ -f "$TMP_BS_GH/.github/ISSUE_TEMPLATE/feature.md" ]'
assert "bootstrap on GitHub: dor-dod workflow scaffolded" '[ -f "$TMP_BS_GH/.github/workflows/dor-dod-enforcement.yml" ]'
rm -rf "$TMP_BS_GH"

# --no-gh-workflow flag suppresses.
TMP_BS_NO=$(mktemp -d)
(cd "$TMP_BS_NO" && git init -q && git remote add origin git@github.com:yusufkaracaburun/testrepo.git)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-rules --no-gh-workflow "$TMP_BS_NO" >/dev/null 2>&1
assert "bootstrap --no-gh-workflow: no .github/ scaffolded" '[ ! -d "$TMP_BS_NO/.github" ]'
rm -rf "$TMP_BS_NO"


print_summary_and_exit
