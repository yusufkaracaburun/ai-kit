#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== ai-kit-upgrade ==="
# section: ai-kit-upgrade
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


echo "=== ai-kit-doctor ==="
# section: ai-kit-doctor
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
ln -s /nonexistent-target "$TMP_DOC/.claude/skills/setup"
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


echo "=== ai-kit-status ==="
# section: ai-kit-status
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


echo "=== verify-setup-minimal ==="
# section: verify-setup-minimal
TMP_MIN=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_MIN"
mkdir -p "$TMP_MIN/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_MIN/docs/agents/"
sed -i '' '/Filled by \/ai:setup/d' "$TMP_MIN/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/ai:setup/d' "$TMP_MIN/docs/agents/dev-environment.md"
printf '\n| Tool | Documentation |\n| ---- | ------------- |\n| nx | https://nx.dev |\n' >> "$TMP_MIN/docs/agents/dev-environment.md"
"$AIKIT/bin/write-setup-marker.sh" "$TMP_MIN" --setup-mode=solo-both --tier=minimal \
  --docker=skipped --tracker=skipped --workflow=skipped --architecture=skipped --sandcastle=false
if "$AIKIT/bin/verify-setup.sh" "$TMP_MIN" --strict --minimal >/dev/null 2>&1; then
  assert "verify minimal tier passes" true
else
  assert "verify minimal tier passes" false
fi
rm -rf "$TMP_MIN"


echo "=== verify-setup ==="
# section: verify-setup
TMP_V=$(mktemp -d)
"$AIKIT/bin/bootstrap-project.sh" --minimal "$TMP_V"
mkdir -p "$TMP_V/docs/agents"
cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$TMP_V/docs/agents/"
sed -i '' '/Filled by \/ai:setup/d' "$TMP_V/docs/agents/dev-environment.md" 2>/dev/null \
  || sed -i '/Filled by \/ai:setup/d' "$TMP_V/docs/agents/dev-environment.md"
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


print_summary_and_exit
