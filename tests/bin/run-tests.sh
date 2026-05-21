#!/usr/bin/env bash
# Regression tests for ai-kit bin scripts.
set -euo pipefail

AIKIT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert() {
  if eval "$2"; then
    echo "  OK: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== detect-package-manager ==="
TMP_PM=$(mktemp -d)
echo '{"name":"t"}' > "$TMP_PM/package.json"
echo "lockfileVersion: 5" > "$TMP_PM/pnpm-lock.yaml"
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/detect-package-manager.sh"
detect_package_manager "$TMP_PM"
assert "pnpm detected" '[ "$PM_NAME" = "pnpm" ]'
assert "pnpm install" '[ "$INSTALL_CMD" = "pnpm install" ]'
rm -rf "$TMP_PM"

TMP_COMP=$(mktemp -d)
echo '{}' > "$TMP_COMP/composer.json"
detect_package_manager "$TMP_COMP"
assert "composer detected" '[ "$PM_NAME" = "composer" ]'
rm -rf "$TMP_COMP"

echo ""
echo "=== detect_architecture ==="
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/detect-lib.sh"

detect_architecture "$AIKIT/tests/fixtures/architecture-laravel"
assert "laravel FE inertia" '[ "$ARCH_FE" = "laravel-inertia" ]'
assert "laravel BE default" '[ "$ARCH_BE" = "laravel-default" ]'
assert "laravel recommend document" '[ "$ARCH_RECOMMENDATION" = "document-existing" ]'

detect_architecture "$AIKIT/tests/fixtures/architecture-fsd"
assert "fsd feature-folders" '[ "$ARCH_FE" = "feature-folders" ]'

echo ""
echo "=== detect_agent_stack ==="
detect_agent_stack "$AIKIT/tests/fixtures/brownfield-custom-skills" "$AIKIT"
assert "custom skill detected" '[[ " ${AGENT_STACK_CURSOR_SKILLS_CUSTOM[*]} " == *" my-custom-skill "* ]]'
assert "recommend brownfield" '[ "$AGENT_STACK_RECOMMENDATION" = "brownfield" ]'
assert "needs doc" '[ "$AGENT_STACK_NEEDS_DOC" = true ]'

JSON_BF="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/brownfield-custom-skills" --json)"
assert "json agent_stack" 'echo "$JSON_BF" | grep -q "\"recommendation\": \"brownfield\""'
assert "json custom skill" 'echo "$JSON_BF" | grep -q "my-custom-skill"'

detect_agent_stack "$AIKIT/tests/fixtures/brownfield-claude-mcp" "$AIKIT"
assert "claude .mcp.json detected" '[[ " ${AGENT_STACK_MCP[*]} " == *" .mcp.json "* ]]'
assert "claude mcp recommends brownfield" '[ "$AGENT_STACK_RECOMMENDATION" = "brownfield" ]'

TMP_MCP=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --with-mcp "$TMP_MCP"
assert "with-mcp creates mcp.json" '[ -f "$TMP_MCP/.cursor/mcp.json" ]'
assert "with-mcp template content" 'grep -q "ai-kit baseline MCP" "$TMP_MCP/.cursor/mcp.json"'
rm -rf "$TMP_MCP"

TMP_MCP_KEEP=$(mktemp -d)
mkdir -p "$TMP_MCP_KEEP/.cursor"
echo '{"existing":true}' > "$TMP_MCP_KEEP/.cursor/mcp.json"
"$AIKIT/bin/bootstrap-project.sh" --minimal --with-mcp "$TMP_MCP_KEEP" >/dev/null
assert "with-mcp preserves existing" 'grep -q "existing" "$TMP_MCP_KEEP/.cursor/mcp.json"'
rm -rf "$TMP_MCP_KEEP"

echo ""
echo "=== detect_bootstrap_state ==="
TMP_BS_MERGE=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --merge-skills "$TMP_BS_MERGE" >/dev/null
detect_bootstrap_state "$TMP_BS_MERGE"
assert "merge-skills detected complete" '[ "$BOOTSTRAP_STATE" = "complete" ]'
assert "merge-skills no missing dirs" '[ "${#BOOTSTRAP_MISSING[@]}" -eq 0 ]'
rm -rf "$TMP_BS_MERGE"

TMP_BS_LINK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --link-all "$TMP_BS_LINK" >/dev/null
detect_bootstrap_state "$TMP_BS_LINK"
assert "link-all detected complete" '[ "$BOOTSTRAP_STATE" = "complete" ]'
rm -rf "$TMP_BS_LINK"

TMP_BS_EMPTY=$(mktemp -d)
detect_bootstrap_state "$TMP_BS_EMPTY"
assert "empty dir detected missing" '[ "$BOOTSTRAP_STATE" = "missing" ]'
assert "missing list mentions .claude/skills" '[[ " ${BOOTSTRAP_MISSING[*]} " == *" .claude/skills "* ]]'
rm -rf "$TMP_BS_EMPTY"

echo ""
echo "=== release.sh ==="
# Dry-run with prepared notes — script must not write anything.
TMP_NOTES="$(mktemp)"
echo "test entry body" > "$TMP_NOTES"
set +e
OUT_REL="$("$AIKIT/bin/release.sh" 9.9.9 --notes-file="$TMP_NOTES" --dry-run 2>&1)"
REL_EXIT=$?
set -e
assert "release: dry-run exits 0" '[ "$REL_EXIT" -eq 0 ]'
assert "release: dry-run announces version" 'echo "$OUT_REL" | grep -q "Would write VERSION = 9.9.9"'
assert "release: dry-run mentions tag" 'echo "$OUT_REL" | grep -q "Would tag: v9.9.9"'

set +e
OUT_BAD="$("$AIKIT/bin/release.sh" notsemver --dry-run 2>&1)"
BAD_EXIT=$?
set -e
assert "release: rejects non-semver" '[ "$BAD_EXIT" -ne 0 ]'

# Same version should be rejected.
CURRENT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"
set +e
OUT_SAME="$("$AIKIT/bin/release.sh" "$CURRENT_VERSION" --notes-file="$TMP_NOTES" --dry-run 2>&1)"
SAME_EXIT=$?
set -e
assert "release: rejects same version" '[ "$SAME_EXIT" -ne 0 ]'
assert "release: --no-tag dry-run skips tag mention" '! "$AIKIT/bin/release.sh" 9.9.8 --notes-file="$TMP_NOTES" --no-tag --dry-run 2>&1 | grep -q "Would tag"'

rm -f "$TMP_NOTES"

echo ""
echo "=== detect-tooling --json ==="
JSON_OUT="$("$AIKIT/bin/detect-tooling.sh" "$AIKIT/tests/fixtures/architecture-laravel" --json)"
assert "json has architecture.frontend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-inertia\""'
assert "json has architecture.backend" 'echo "$JSON_OUT" | grep -q "\"detected\": \"laravel-default\""'

echo ""
echo "=== bootstrap ==="
TMP_BOOT=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_BOOT"
assert "AGENTS.md" '[ -f "$TMP_BOOT/AGENTS.md" ]'
assert ".claude/skills dir" '[ -d "$TMP_BOOT/.claude/skills" ]'
assert ".claude/skills setup linked" '[ -L "$TMP_BOOT/.claude/skills/setup" ] || [ -d "$TMP_BOOT/.claude/skills/setup" ]'
assert ".agents/skills dir" '[ -d "$TMP_BOOT/.agents/skills" ]'
assert ".cursor/skills dir" '[ -d "$TMP_BOOT/.cursor/skills" ]'
assert "setup skill linked" '[ -L "$TMP_BOOT/.cursor/skills/setup" ] || [ -d "$TMP_BOOT/.cursor/skills/setup" ]'
assert "ai-kit.mdc" '[ -f "$TMP_BOOT/.cursor/rules/ai-kit.mdc" ]'
# Every generated .mdc must have Cursor's required frontmatter keys.
MDC_INVALID=""
for mdc in "$TMP_BOOT/.cursor/rules"/*.mdc; do
  for key in description globs alwaysApply; do
    if ! head -8 "$mdc" | grep -qE "^${key}:"; then
      MDC_INVALID="${MDC_INVALID}$(basename "$mdc")(missing:$key) "
    fi
  done
done
assert "all .mdc rules have Cursor frontmatter" '[ -z "$MDC_INVALID" ]'
assert "no docker.md yet" '[ ! -f "$TMP_BOOT/docs/agents/docker.md" ]'
rm -rf "$TMP_BOOT"

TMP_LINK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --link-all "$TMP_LINK"
assert "link-all .claude symlink" '[ -L "$TMP_LINK/.claude/skills" ]'
assert "link-all symlink" '[ -L "$TMP_LINK/.cursor/skills" ]'
rm -rf "$TMP_LINK"

TMP_MERGE=$(mktemp -d)
cp -R "$AIKIT/tests/fixtures/brownfield-custom-skills/.cursor" "$TMP_MERGE/"
"$AIKIT/bin/bootstrap-project.sh" --minimal --merge-skills "$TMP_MERGE"
assert "merge keeps custom skill" '[ -d "$TMP_MERGE/.cursor/skills/my-custom-skill" ] || [ -L "$TMP_MERGE/.cursor/skills/my-custom-skill" ]'
assert "merge adds setup" '[ -e "$TMP_MERGE/.cursor/skills/setup" ]'
assert "merge adds .claude/skills/setup" '[ -e "$TMP_MERGE/.claude/skills/setup" ]'
rm -rf "$TMP_MERGE"

TMP_NO_SK=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal --no-skills "$TMP_NO_SK"
assert "no-skills AGENTS.md" '[ -f "$TMP_NO_SK/AGENTS.md" ]'
assert "no-skills skips .claude/skills" '[ ! -e "$TMP_NO_SK/.claude/skills" ]'
assert "no-skills skips .agents/skills" '[ ! -e "$TMP_NO_SK/.agents/skills" ]'
assert "no-skills skips .cursor/skills" '[ ! -e "$TMP_NO_SK/.cursor/skills" ]'
rm -rf "$TMP_NO_SK"

echo ""
echo "=== apply-docker ==="
TMP_D=$(mktemp -d)
mkdir -p "$TMP_D/docs/agents"
"$AIKIT/bin/apply-docker.sh" "$TMP_D" none
assert "docker none" '[ -f "$TMP_D/docs/agents/docker.md" ] && grep -q none "$TMP_D/.ai-kit-docker"'
"$AIKIT/bin/apply-docker.sh" "$TMP_D" existing
assert "docker existing" 'grep -q existing "$TMP_D/.ai-kit-docker"'
rm -rf "$TMP_D"

echo ""
echo "=== apply-sandcastle ==="
TMP_SC=$(mktemp -d)
echo '{"name":"t"}' > "$TMP_SC/package.json"
echo "lockfileVersion: 5" > "$TMP_SC/pnpm-lock.yaml"
"$AIKIT/bin/apply-sandcastle.sh" "$TMP_SC"
assert "sandcastle dir" '[ -d "$TMP_SC/.sandcastle" ]'
assert "pnpm in main.mts" 'grep -q "pnpm install" "$TMP_SC/.sandcastle/main.mts"'
assert "no placeholder" '! grep -q "{{INSTALL_CMD}}" "$TMP_SC/.sandcastle/main.mts"'
rm -rf "$TMP_SC"

echo ""
echo "=== write-setup-marker ==="
TMP_M=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --setup-mode=solo-both --tier=minimal --architecture=skipped --docker=skipped --tracker=skipped --workflow=skipped --sandcastle=false
assert "marker exists" '[ -f "$TMP_M/.ai-kit-setup" ]'
assert "setup_mode solo-both" 'grep -q "\"setup_mode\": \"solo-both\"" "$TMP_M/.ai-kit-setup"'
assert "tier minimal" 'grep -q "\"setup_tier\": \"minimal\"" "$TMP_M/.ai-kit-setup"'
EXPECTED_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"
assert "marker carries current version" 'grep -q "\"ai_kit_version\": \"$EXPECTED_VERSION\"" "$TMP_M/.ai-kit-setup"'
assert "no key without flag (backward compat)" '! grep -q "automation_recommender" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --architecture=skipped
assert "architecture merge skip" 'grep -q "\"architecture\": \"skipped\"" "$TMP_M/.ai-kit-setup"'
rm -rf "$TMP_M"

echo ""
echo "=== automation-recommender flag ==="
TMP_AR=$(mktemp -d)
for VAL in skipped deferred completed; do
  "$AIKIT/bin/write-setup-marker.sh" "$TMP_AR" --setup-mode=solo-both --tier=minimal --automation-recommender="$VAL"
  assert "round-trip $VAL" 'grep -q "\"automation_recommender\": \"'"$VAL"'\"" "$TMP_AR/.ai-kit-setup"'
done
"$AIKIT/bin/write-setup-marker.sh" "$TMP_AR" --architecture=documented
assert "idempotent: recommender preserved across re-write" 'grep -q "\"automation_recommender\": \"completed\"" "$TMP_AR/.ai-kit-setup"'
assert "idempotent: architecture added" 'grep -q "\"architecture\": \"documented\"" "$TMP_AR/.ai-kit-setup"'
rm -rf "$TMP_AR"

echo ""
echo "=== ai-kit-upgrade ==="
TMP_UP=$(mktemp -d)
cat > "$TMP_UP/.ai-kit-setup" <<'JSON'
{
  "ai_kit_version": "0.0.1",
  "completed_at": "2020-01-01T00:00:00Z",
  "branches": {
    "bootstrap": true,
    "dev_environment": true,
    "setup_mode": "solo-both",
    "setup_tier": "full",
    "docker": "none",
    "issue_tracker": "github",
    "workflow": "informal",
    "architecture": "document-existing",
    "sandcastle": false,
    "automation_recommender": "deferred"
  }
}
JSON
"$AIKIT/bin/ai-kit-upgrade.sh" "$TMP_UP" >/dev/null
CURRENT_VERSION="$(tr -d '[:space:]' < "$AIKIT/VERSION")"
assert "upgrade stamps current version" 'grep -q "\"ai_kit_version\": \"$CURRENT_VERSION\"" "$TMP_UP/.ai-kit-setup"'
assert "upgrade preserves branches" 'grep -q "\"automation_recommender\": \"deferred\"" "$TMP_UP/.ai-kit-setup"'
assert "upgrade preserves tracker" 'grep -q "\"issue_tracker\": \"github\"" "$TMP_UP/.ai-kit-setup"'
assert "upgrade preserves architecture" 'grep -q "\"architecture\": \"document-existing\"" "$TMP_UP/.ai-kit-setup"'
rm -rf "$TMP_UP"

TMP_UP_FAIL=$(mktemp -d)
if "$AIKIT/bin/ai-kit-upgrade.sh" "$TMP_UP_FAIL" >/dev/null 2>&1; then
  assert "upgrade fails without marker" false
else
  assert "upgrade fails without marker" true
fi
rm -rf "$TMP_UP_FAIL"

echo ""
echo "=== ai-kit-doctor ==="
TMP_DOC=$(mktemp -d)
# No project arg — should run env + global checks only.
set +e
OUT_DOC_NO_PROJ="$("$AIKIT/bin/ai-kit-doctor.sh" 2>&1)"
set -e
assert "doctor: shows env section" 'echo "$OUT_DOC_NO_PROJ" | grep -q "^Env"'
assert "doctor: checks python3" 'echo "$OUT_DOC_NO_PROJ" | grep -q "python3"'
assert "doctor: shows global install section" 'echo "$OUT_DOC_NO_PROJ" | grep -q "Global install"'

# Bootstrapped project — symlinks should resolve.
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_DOC" >/dev/null
set +e
OUT_DOC_PROJ="$("$AIKIT/bin/ai-kit-doctor.sh" "$TMP_DOC" 2>&1)"
set -e
assert "doctor: project section present" 'echo "$OUT_DOC_PROJ" | grep -q "Project:"'
assert "doctor: skills resolve" 'echo "$OUT_DOC_PROJ" | grep -q ".claude/skills.*entries resolve"'
assert "doctor: marker absent flagged" 'echo "$OUT_DOC_PROJ" | grep -q ".ai-kit-setup absent"'

# Broken symlink — simulate ai-kit moved.
rm -f "$TMP_DOC/.claude/skills/setup"
ln -s /nonexistent-aikit-target "$TMP_DOC/.claude/skills/setup"
set +e
OUT_DOC_BROKEN="$("$AIKIT/bin/ai-kit-doctor.sh" "$TMP_DOC" 2>&1)"
DOC_BROKEN_EXIT=$?
set -e
assert "doctor: broken link surfaced" 'echo "$OUT_DOC_BROKEN" | grep -q "broken symlinks"'
assert "doctor: exit 2 on error" '[ "$DOC_BROKEN_EXIT" -eq 2 ]'

rm -rf "$TMP_DOC"

# Mode-aware: project-only marker should skip global checks.
TMP_DOC_PO=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_DOC_PO" >/dev/null
"$AIKIT/bin/write-setup-marker.sh" "$TMP_DOC_PO" --setup-mode=project-only --tier=minimal >/dev/null
set +e
OUT_PO="$("$AIKIT/bin/ai-kit-doctor.sh" "$TMP_DOC_PO" 2>&1)"
PO_EXIT=$?
set -e
assert "doctor: project-only skips globals" 'echo "$OUT_PO" | grep -q "skipped — setup-mode is project-only"'
assert "doctor: project-only exit 0" '[ "$PO_EXIT" -eq 0 ]'

# Explicit --project-only without a project arg should also skip.
set +e
OUT_PO_FLAG="$("$AIKIT/bin/ai-kit-doctor.sh" --project-only 2>&1)"
set -e
assert "doctor: --project-only flag works without project" 'echo "$OUT_PO_FLAG" | grep -q "skipped — setup-mode is project-only"'

rm -rf "$TMP_DOC_PO"

# Machine opt-out: when no project context + opt-out file present, skip globals.
TMP_HOME_OO="$(mktemp -d)"
mkdir -p "$TMP_HOME_OO/.config/ai-kit"
: > "$TMP_HOME_OO/.config/ai-kit/no-globals"

set +e
# AI_KIT_ROOT set so the env section is clean — we're isolating the opt-out
# effect, not the env check.
OUT_OO_NOPROJ="$(HOME="$TMP_HOME_OO" AI_KIT_ROOT="$AIKIT" "$AIKIT/bin/ai-kit-doctor.sh" 2>&1)"
OO_NOPROJ_EXIT=$?
set -e
assert "doctor: machine opt-out skips globals (no project arg)" 'echo "$OUT_OO_NOPROJ" | grep -q "machine opt-out"'
assert "doctor: opt-out alone exits 0" '[ "$OO_NOPROJ_EXIT" -eq 0 ]'

# Project with non-project-only setup-mode must override the machine opt-out.
TMP_OO_PROJ=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_OO_PROJ" >/dev/null
"$AIKIT/bin/write-setup-marker.sh" "$TMP_OO_PROJ" --setup-mode=solo-both --tier=minimal >/dev/null
set +e
OUT_OO_PROJ="$(HOME="$TMP_HOME_OO" "$AIKIT/bin/ai-kit-doctor.sh" "$TMP_OO_PROJ" 2>&1)"
set -e
assert "doctor: project solo-both overrides opt-out" '! echo "$OUT_OO_PROJ" | grep -q "machine opt-out"'
rm -rf "$TMP_OO_PROJ" "$TMP_HOME_OO"

# ai-kit-no-globals.sh CLI lifecycle: on -> off -> status.
TMP_HOME_NG="$(mktemp -d)"
HOME="$TMP_HOME_NG" "$AIKIT/bin/ai-kit-no-globals.sh" on >/dev/null
assert "no-globals on: creates marker" '[ -f "$TMP_HOME_NG/.config/ai-kit/no-globals" ]'
assert "no-globals status: reports ON" 'HOME="$TMP_HOME_NG" "$AIKIT/bin/ai-kit-no-globals.sh" status | grep -q "Opt-out: ON"'
HOME="$TMP_HOME_NG" "$AIKIT/bin/ai-kit-no-globals.sh" off >/dev/null
assert "no-globals off: removes marker" '[ ! -f "$TMP_HOME_NG/.config/ai-kit/no-globals" ]'
assert "no-globals status: reports OFF" 'HOME="$TMP_HOME_NG" "$AIKIT/bin/ai-kit-no-globals.sh" status | grep -q "Opt-out: OFF"'
rm -rf "$TMP_HOME_NG"

echo ""
echo "=== ai-kit-status ==="
TMP_ST=$(mktemp -d)
OUT_NO_MARKER="$("$AIKIT/bin/ai-kit-status.sh" "$TMP_ST" 2>&1)"
assert "status: marker absent" 'echo "$OUT_NO_MARKER" | grep -q "Marker:.*absent"'
assert "status: shows ai-kit version line" 'echo "$OUT_NO_MARKER" | grep -q "ai-kit @"'

"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_ST" >/dev/null
"$AIKIT/bin/write-setup-marker.sh" "$TMP_ST" --setup-mode=solo-both --tier=full --sandcastle=false --automation-recommender=deferred >/dev/null
OUT_OK="$("$AIKIT/bin/ai-kit-status.sh" "$TMP_ST" 2>&1)"
assert "status: marker present line" 'echo "$OUT_OK" | grep -q "Marker:.*$(tr -d "[:space:]" < "$AIKIT/VERSION")"'
assert "status: branches line" 'echo "$OUT_OK" | grep -q "Branches:"'
assert "status: bool formatted as false" 'echo "$OUT_OK" | grep -q "sandcastle=false"'
assert "status: deferred surfaced" 'echo "$OUT_OK" | grep -q "Deferred: recommender"'
assert "status: skills counted" 'echo "$OUT_OK" | grep -qE "\.claude/skills: [0-9]+ skills"'

# Drift detection
python3 -c "import json; p='$TMP_ST/.ai-kit-setup'; d=json.load(open(p)); d['ai_kit_version']='0.0.1'; json.dump(d, open(p,'w'), indent=2)"
OUT_DRIFT="$("$AIKIT/bin/ai-kit-status.sh" "$TMP_ST" 2>&1)"
assert "status: drift advisory shown" 'echo "$OUT_DRIFT" | grep -q "drift vs ai-kit"'
rm -rf "$TMP_ST"

echo ""
echo "=== verify-setup minimal ==="
TMP_MIN=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_MIN"
mkdir -p "$TMP_MIN/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_MIN/docs/agents/"
sed -i '' '/Filled by \/setup/d' "$TMP_MIN/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/setup/d' "$TMP_MIN/docs/agents/dev-environment.md"
printf '\n| Tool | Documentation |\n| ---- | ------------- |\n| nx | https://nx.dev |\n' >> "$TMP_MIN/docs/agents/dev-environment.md"
"$AIKIT/bin/write-setup-marker.sh" "$TMP_MIN" --setup-mode=solo-both --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
if "$AIKIT/bin/verify-setup.sh" "$TMP_MIN" --strict --minimal >/dev/null 2>&1; then
  assert "verify minimal tier passes" true
else
  assert "verify minimal tier passes" false
fi
rm -rf "$TMP_MIN"

echo ""
echo "=== verify-setup ==="
TMP_V=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_V"
mkdir -p "$TMP_V/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_V/docs/agents/"
sed -i '' '/Filled by \/setup/d' "$TMP_V/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/setup/d' "$TMP_V/docs/agents/dev-environment.md"
printf '\n| Tool | Documentation |\n| ---- | ------------- |\n| ai-kit | https://github.com |\n' >> "$TMP_V/docs/agents/dev-environment.md"
cp "$AIKIT/context/templates/docs/agents/issue-tracker-github.md" "$TMP_V/docs/agents/issue-tracker.md"
cp "$AIKIT/context/templates/docs/agents/triage-labels.md" "$TMP_V/docs/agents/"
cp "$AIKIT/context/templates/docs/agents/domain.md" "$TMP_V/docs/agents/"
cp "$AIKIT/context/templates/docs/agents/workflow.md" "$TMP_V/docs/agents/"
"$AIKIT/bin/apply-docker.sh" "$TMP_V" none
"$AIKIT/bin/write-setup-marker.sh" "$TMP_V" --setup-mode=solo-both --tier=full --architecture=skipped --docker=none --tracker=github --workflow=informal --sandcastle=false --automation-recommender=deferred
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" >/dev/null 2>&1; then
  assert "verify skipped arch passes" true
else
  assert "verify skipped arch passes" false
fi
"$AIKIT/bin/write-setup-marker.sh" "$TMP_V" --architecture=documented
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" >/dev/null 2>&1; then
  assert "verify fails without architecture.md" false
else
  assert "verify fails without architecture.md" true
fi
cp "$AIKIT/context/templates/docs/agents/architecture.md" "$TMP_V/docs/agents/"
sed -i '' 's/\[e.g. follow existing layout | co-located components | feature folders | FSD-like | pages\/routes\]/Feature folders (detected)/' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[e.g. follow existing layout | co-located components | feature folders | FSD-like | pages\/routes\]/Feature folders (detected)/' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[key paths, e.g. src\/features\/, app\/pages\/\]/src\/features\//' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[key paths, e.g. src\/features\/, app\/pages\/\]/src\/features\//' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[e.g. framework defaults | layered | actions | ports-adapters | modular monolith\]/Laravel MVC/' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[e.g. framework defaults | layered | actions | ports-adapters | modular monolith\]/Laravel MVC/' "$TMP_V/docs/agents/architecture.md"
sed -i '' 's/\[key paths, e.g. app\/Actions\/, src\/Domain\/\]/app\/Http\/Controllers\//' "$TMP_V/docs/agents/architecture.md" 2>/dev/null \
  || sed -i 's/\[key paths, e.g. app\/Actions\/, src\/Domain\/\]/app\/Http\/Controllers\//' "$TMP_V/docs/agents/architecture.md"
if "$AIKIT/bin/verify-setup.sh" "$TMP_V" --strict >/dev/null 2>&1; then
  assert "verify strict with filled architecture" true
else
  assert "verify strict with filled architecture" false
fi
rm -rf "$TMP_V"

echo ""
echo "=== agents-patch ==="
TMP_P=$(mktemp -d)
cp "$AIKIT/context/templates/AGENTS.md.template" "$TMP_P/AGENTS.md"
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/agents-patch.sh"
patch_agents_docker_section "$TMP_P"
assert "docker section patched" 'grep -q "### Docker" "$TMP_P/AGENTS.md"'
patch_agents_docker_section "$TMP_P"
assert "idempotent patch" '[ "$(grep -c "### Docker" "$TMP_P/AGENTS.md")" -eq 1 ]'
rm -rf "$TMP_P"

echo ""
echo "=== ai-kit-root ==="
# shellcheck source=/dev/null
source "$AIKIT/bin/lib/ai-kit-root.sh"
ROOT_SCRIPT="$(resolve_ai_kit_root "$AIKIT/bin")"
assert "resolves from script path" '[ "$ROOT_SCRIPT" = "$AIKIT" ]'

TMP_HOME=$(mktemp -d)
export AI_KIT_ROOT=""
HOME="$TMP_HOME" write_ai_kit_root_config "$AIKIT"
ROOT_CFG="$(HOME="$TMP_HOME" resolve_ai_kit_root "")"
assert "resolves from config file" '[ "$ROOT_CFG" = "$AIKIT" ]'

export AI_KIT_ROOT="$AIKIT"
ROOT_ENV="$(resolve_ai_kit_root "")"
assert "resolves from AI_KIT_ROOT env" '[ "$ROOT_ENV" = "$AIKIT" ]'
unset AI_KIT_ROOT
rm -rf "$TMP_HOME"

CLI_OUT="$("$AIKIT/bin/ai-kit-root.sh")"
assert "ai-kit-root.sh CLI" '[ "$CLI_OUT" = "$AIKIT" ]'

echo ""
echo "=== install.sh ==="
# Help text
OUT_INSTALL_HELP="$("$AIKIT/install.sh" --help 2>&1)"
assert "install: help text" 'echo "$OUT_INSTALL_HELP" | grep -q "ai-kit installer"'
assert "install: lists --no-global" 'echo "$OUT_INSTALL_HELP" | grep -q -- "--no-global"'

# Clone from local repo with --no-global (end-to-end without touching ~/.claude).
TMP_HOME_INSTALL="$(mktemp -d)"
TMP_DIR_INSTALL="$TMP_HOME_INSTALL/.local/share/ai-kit"
HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --repo="$AIKIT" --dir="$TMP_DIR_INSTALL" --no-global --quiet
assert "install: clones into target dir" '[ -f "$TMP_DIR_INSTALL/VERSION" ]'
assert "install: writes ~/.config/ai-kit/root" '[ -f "$TMP_HOME_INSTALL/.config/ai-kit/root" ]'
assert "install: --no-global skips ~/.claude/skills" '[ ! -d "$TMP_HOME_INSTALL/.claude/skills" ]'

# Idempotent rerun — should detect existing install, not re-clone.
OUT_RERUN="$(HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --repo="$AIKIT" --dir="$TMP_DIR_INSTALL" --no-global 2>&1)"
assert "install: rerun detects existing" 'echo "$OUT_RERUN" | grep -q "already installed"'

# Refuse to clobber a non-aikit directory.
BAD_DIR_INSTALL="$(mktemp -d)"
touch "$BAD_DIR_INSTALL/foo.txt"
set +e
OUT_BAD="$(HOME="$TMP_HOME_INSTALL" "$AIKIT/install.sh" --dir="$BAD_DIR_INSTALL" --no-global 2>&1)"
BAD_EXIT=$?
set -e
assert "install: refuses to clobber non-aikit dir" '[ "$BAD_EXIT" -ne 0 ] && echo "$OUT_BAD" | grep -q "not an ai-kit clone"'

# Unknown flag exits 2.
set +e
"$AIKIT/install.sh" --bogus 2>/dev/null
INSTALL_BAD_FLAG_EXIT=$?
set -e
assert "install: unknown flag exits 2" '[ "$INSTALL_BAD_FLAG_EXIT" -eq 2 ]'

rm -rf "$TMP_HOME_INSTALL" "$BAD_DIR_INSTALL"

echo ""
echo "=== skills count ==="
SKILL_COUNT=$(find "$AIKIT/workflow/skills" -name SKILL.md | wc -l | tr -d ' ')
assert "16 skills" '[ "$SKILL_COUNT" -eq 16 ]'

echo ""
echo "=== VERSION ==="
assert "VERSION file" '[ -f "$AIKIT/VERSION" ]'

echo ""
echo "=== eval-structure ==="
if "$AIKIT/tests/bin/eval-structure.sh" > /tmp/eval-structure.out 2>&1; then
  STRUCT_OK=true
else
  STRUCT_OK=false
  echo "  (eval-structure.sh failures — see /tmp/eval-structure.out)"
  tail -20 /tmp/eval-structure.out
fi
assert "eval-structure clean" '[ "$STRUCT_OK" = true ]'

echo ""
echo "=== usage logging ==="
USAGE_STATE=$(mktemp -d)
unset AI_KIT_USAGE
"$AIKIT/bin/log-skill.sh" diagnose start 2>/dev/null
assert "log-skill no-op without env" '[ ! -f "$USAGE_STATE/ai-kit/usage.jsonl" ]'

XDG_STATE_HOME="$USAGE_STATE" AI_KIT_USAGE=1 "$AIKIT/bin/log-skill.sh" diagnose start
XDG_STATE_HOME="$USAGE_STATE" AI_KIT_USAGE=1 "$AIKIT/bin/log-skill.sh" diagnose "done"
assert "log-skill writes one line per event" '[ "$(wc -l < "$USAGE_STATE/ai-kit/usage.jsonl" | tr -d " ")" = "2" ]'
assert "log line has skill" 'grep -q "\"skill\":\"diagnose\"" "$USAGE_STATE/ai-kit/usage.jsonl"'
assert "log line has no absolute path" '! grep -q "/Users/" "$USAGE_STATE/ai-kit/usage.jsonl"'

STATS_OUT="$(XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-stats.sh" --since=all)"
assert "usage-stats reports diagnose" 'echo "$STATS_OUT" | grep -q "diagnose"'

JSON_OUT="$(XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-stats.sh" --json)"
assert "usage-stats --json parses" 'echo "$JSON_OUT" | grep -q "\"events\":2"'

XDG_STATE_HOME="$USAGE_STATE" "$AIKIT/bin/usage-purge.sh" --yes >/dev/null
assert "usage-purge removes log" '[ ! -f "$USAGE_STATE/ai-kit/usage.jsonl" ]'
rm -rf "$USAGE_STATE"

echo ""
echo "=== privacy ==="
NET_HITS="$(grep -REn 'curl|wget|/dev/tcp|nc ' "$AIKIT/bin/log-skill.sh" "$AIKIT/bin/usage-stats.sh" "$AIKIT/bin/usage-purge.sh" || true)"
assert "no network calls in usage scripts" '[ -z "$NET_HITS" ]'

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All $PASS tests passed."
  exit 0
else
  echo "$FAIL failed, $PASS passed."
  exit 1
fi
