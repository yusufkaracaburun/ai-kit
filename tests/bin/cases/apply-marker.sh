#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"


echo "=== apply-docker ==="
# section: apply-docker
TMP_D=$(mktemp -d)
mkdir -p "$TMP_D/docs/agents"
"$AIKIT/bin/apply-docker.sh" "$TMP_D" none
assert "docker none" '[ -f "$TMP_D/docs/agents/docker.md" ] && grep -q none "$TMP_D/.ai-kit-docker"'
"$AIKIT/bin/apply-docker.sh" "$TMP_D" existing
assert "docker existing" 'grep -q existing "$TMP_D/.ai-kit-docker"'
rm -rf "$TMP_D"


echo "=== apply-sandcastle ==="
# section: apply-sandcastle
TMP_SC=$(mktemp -d)
echo '{"name":"t"}' > "$TMP_SC/package.json"
echo "lockfileVersion: 5" > "$TMP_SC/pnpm-lock.yaml"
"$AIKIT/bin/apply-sandcastle.sh" "$TMP_SC"
assert "sandcastle dir" '[ -d "$TMP_SC/.sandcastle" ]'
assert "pnpm in main.mts" 'grep -q "pnpm install" "$TMP_SC/.sandcastle/main.mts"'
assert "no placeholder" '! grep -q "{{INSTALL_CMD}}" "$TMP_SC/.sandcastle/main.mts"'
rm -rf "$TMP_SC"


echo "=== write-setup-marker ==="
# section: write-setup-marker
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
assert "no context_drift_hook key without flag" '! grep -q "context_drift_hook" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --context-drift-hook=wired
assert "context-drift-hook round-trips" 'grep -q "\"context_drift_hook\": \"wired\"" "$TMP_M/.ai-kit-setup"'
assert "context-drift-hook write preserves setup_mode" 'grep -q "\"setup_mode\": \"solo-both\"" "$TMP_M/.ai-kit-setup"'
assert "no rule_recommendation key without flag" '! grep -q "rule_recommendation" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --rule-recommendation=deferred
assert "rule-recommendation round-trips" 'grep -q "\"rule_recommendation\": \"deferred\"" "$TMP_M/.ai-kit-setup"'
assert "rule-recommendation write preserves setup_mode" 'grep -q "\"setup_mode\": \"solo-both\"" "$TMP_M/.ai-kit-setup"'
assert "no domain_docs key without flag (decoupled from tracker)" '! grep -q "domain_docs" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --domain-docs=scaffolded
assert "domain-docs round-trips scaffolded" 'grep -q "\"domain_docs\": \"scaffolded\"" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --domain-docs=filled
assert "domain-docs round-trips filled" 'grep -q "\"domain_docs\": \"filled\"" "$TMP_M/.ai-kit-setup"'
"$AIKIT/bin/write-setup-marker.sh" "$TMP_M" --domain-docs=skipped
assert "domain-docs round-trips skipped" 'grep -q "\"domain_docs\": \"skipped\"" "$TMP_M/.ai-kit-setup"'
TMP_DD=$(mktemp -d)
"$AIKIT/bin/write-setup-marker.sh" "$TMP_DD" --setup-mode=solo-both --tier=full --tracker=github
assert "tracker=github no longer auto-sets domain_docs" '! grep -q "domain_docs" "$TMP_DD/.ai-kit-setup"'
assert "tracker=github still sets triage_labels" 'grep -q "\"triage_labels\": true" "$TMP_DD/.ai-kit-setup"'
rm -rf "$TMP_DD"
rm -rf "$TMP_M"


echo "=== automation-recommender-flag ==="
# section: automation-recommender-flag
TMP_AR=$(mktemp -d)
for VAL in skipped deferred completed; do
  "$AIKIT/bin/write-setup-marker.sh" "$TMP_AR" --setup-mode=solo-both --tier=minimal --automation-recommender="$VAL"
  assert "round-trip $VAL" 'grep -q "\"automation_recommender\": \"'"$VAL"'\"" "$TMP_AR/.ai-kit-setup"'
done
"$AIKIT/bin/write-setup-marker.sh" "$TMP_AR" --architecture=documented
assert "idempotent: recommender preserved across re-write" 'grep -q "\"automation_recommender\": \"completed\"" "$TMP_AR/.ai-kit-setup"'
assert "idempotent: architecture added" 'grep -q "\"architecture\": \"documented\"" "$TMP_AR/.ai-kit-setup"'
rm -rf "$TMP_AR"


echo "=== apply-context-drift-hook ==="
# section: apply-context-drift-hook
TMP_CDH=$(mktemp -d)
"$AIKIT/bin/apply-context-drift-hook.sh" "$TMP_CDH" >/dev/null
assert "hook copied into project" '[ -x "$TMP_CDH/.claude/hooks/context-drift-check.sh" ]'
assert "settings.json created" '[ -f "$TMP_CDH/.claude/settings.json" ]'
assert "settings.json is valid JSON" 'python3 -c "import json; json.load(open(\"$TMP_CDH/.claude/settings.json\"))"'
assert "PostToolUse entry wired" 'python3 -c "import json; d=json.load(open(\"$TMP_CDH/.claude/settings.json\")); assert any(h[\"command\"].endswith(\"context-drift-check.sh\") for b in d[\"hooks\"][\"PostToolUse\"] for h in b[\"hooks\"])"'
"$AIKIT/bin/apply-context-drift-hook.sh" "$TMP_CDH" >/dev/null
assert "apply is idempotent (no duplicate)" 'python3 -c "import json; d=json.load(open(\"$TMP_CDH/.claude/settings.json\")); n=sum(1 for b in d[\"hooks\"][\"PostToolUse\"] for h in b[\"hooks\"] if h[\"command\"].endswith(\"context-drift-check.sh\")); assert n==1, n"'
rm -rf "$TMP_CDH"

TMP_CDH2=$(mktemp -d)
mkdir -p "$TMP_CDH2/.claude"
printf '{\n  "hooks": {\n    "PostToolUse": [\n      { "matcher": "^Skill$", "hooks": [{ "type": "command", "command": "existing.sh" }] }\n    ]\n  }\n}\n' > "$TMP_CDH2/.claude/settings.json"
"$AIKIT/bin/apply-context-drift-hook.sh" "$TMP_CDH2" >/dev/null
assert "apply preserves a pre-existing hook" 'grep -q "existing.sh" "$TMP_CDH2/.claude/settings.json"'
assert "apply adds context-drift alongside" 'grep -q "context-drift-check.sh" "$TMP_CDH2/.claude/settings.json"'
rm -rf "$TMP_CDH2"


print_summary_and_exit
