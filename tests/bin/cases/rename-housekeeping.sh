#!/usr/bin/env bash
# Test fixtures for /ai:rename-housekeeping primitives.
#
#   1. fake-rename       — core script rewrites 3 memory files + leaves 3 backups
#   2. multi-clone-guard — hook emits NO warning when both paths still exist
#   3. hook-rename       — hook emits warning when old path is gone
#   4. structure         — skill, hook, installer files exist with correct frontmatter
#
# Run: tests/bin/cases/rename-housekeeping.sh
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

CORE="$AIKIT/bin/rename-housekeeping-core.sh"
HOOK="$AIKIT/bin/hooks/rename-detector.sh"
INSTALLER="$AIKIT/bin/install-rename-hook.sh"
SKILL="$AIKIT/workflow/skills/rename-housekeeping/SKILL.md"

mktmpdir() { mktemp -d "${TMPDIR:-/tmp}/ai-kit-rename-XXXXXX"; }

# ---------------------------------------------------------------------------
echo "=== structure ==="
# section: structure
assert "skill SKILL.md exists"            "[ -f '$SKILL' ]"
assert "skill frontmatter name"           "head -5 '$SKILL' | grep -q '^name: rename-housekeeping$'"
assert "skill frontmatter description"    "head -5 '$SKILL' | grep -q '^description:'"
assert "skill mentions auto-trigger verbs" "grep -qE 'renamed|moved|verplaatst|hernoemd' '$SKILL'"
assert "skill references core script"     "grep -q 'rename-housekeeping-core.sh' '$SKILL'"
assert "core script exists + executable"  "[ -x '$CORE' ]"
assert "hook exists + executable"         "[ -x '$HOOK' ]"
assert "installer exists + executable"    "[ -x '$INSTALLER' ]"
assert "core script syntax OK"            "bash -n '$CORE'"
assert "hook syntax OK"                   "bash -n '$HOOK'"
assert "installer syntax OK"              "bash -n '$INSTALLER'"

# ---------------------------------------------------------------------------
echo "=== fake-rename ==="
# section: fake-rename — 3 memory files reference OLD; after apply, 0 stale refs + 3 backups
TMP=$(mktmpdir)
FAKE_HOME="$TMP/home"
FAKE_REPO="$TMP/repo"
OLD="school-activities-hub"
NEW="naschool"

mkdir -p "$FAKE_HOME/.claude/rules" \
         "$FAKE_HOME/.claude/projects/-x/memory" \
         "$FAKE_REPO/.agents/memory" \
         "$FAKE_REPO/.planning/phases/14" \
         "$FAKE_REPO/docs/adr"

# Three files mentioning OLD — one under ~/.claude/ (backup target), two under <repo>.
echo "cd /Users/y/Sites/localhost/$OLD/backend" > "$FAKE_HOME/.claude/CLAUDE.md"
echo "path: /Users/y/Sites/localhost/$OLD"      > "$FAKE_HOME/.claude/projects/-x/memory/foo.md"
echo "project: $OLD"                            > "$FAKE_REPO/.agents/memory/state.md"
echo "phase 14: $OLD live e2e"                  > "$FAKE_REPO/.planning/phases/14/SUMMARY.md"

# Scan should find 4 hits across 4 files.
SCAN_OUT=$("$CORE" scan "$OLD" "$NEW" --repo "$FAKE_REPO" --home "$FAKE_HOME" || true)
SCAN_FILES=$(printf "%s\n" "$SCAN_OUT" | awk -F'\t' '{print $1}' | sort -u | wc -l | tr -d ' ')
assert "scan finds 4 files with hits" "[ '$SCAN_FILES' = '4' ]"

# Apply rewrites everything + creates backups for ~/.claude/** targets.
APPLY_OUT=$("$CORE" apply "$OLD" "$NEW" --repo "$FAKE_REPO" --home "$FAKE_HOME")
echo "$APPLY_OUT"

# Post-condition 1: 0 stale OLD refs across all 4 files.
STALE=$( { grep -lF "$OLD" \
  "$FAKE_HOME/.claude/CLAUDE.md" \
  "$FAKE_HOME/.claude/projects/-x/memory/foo.md" \
  "$FAKE_REPO/.agents/memory/state.md" \
  "$FAKE_REPO/.planning/phases/14/SUMMARY.md" 2>/dev/null || true; } | wc -l | tr -d ' ')
assert "0 stale OLD refs remain" "[ '$STALE' = '0' ]"

# Post-condition 2: 4 files now contain NEW.
NEW_HITS=$( { grep -lF "$NEW" \
  "$FAKE_HOME/.claude/CLAUDE.md" \
  "$FAKE_HOME/.claude/projects/-x/memory/foo.md" \
  "$FAKE_REPO/.agents/memory/state.md" \
  "$FAKE_REPO/.planning/phases/14/SUMMARY.md" 2>/dev/null || true; } | wc -l | tr -d ' ')
assert "4 files now contain NEW" "[ '$NEW_HITS' = '4' ]"

# Post-condition 3: 2 backups under ~/.claude/.backups/<ts>/  (CLAUDE.md + foo.md).
BACKUP_DIR=$(find "$FAKE_HOME/.claude/.backups" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1 || true)
BACKUP_COUNT=$( { find "$BACKUP_DIR" -type f 2>/dev/null || true; } | wc -l | tr -d ' ')
assert "2 backups created for ~/.claude/** targets" "[ '$BACKUP_COUNT' = '2' ]"

# Post-condition 4: project-local files NOT backed up (git is their safety net).
PROJECT_BACKUP_HITS=$( { find "$BACKUP_DIR" -type f 2>/dev/null || true; } | { xargs grep -lF "phase 14" 2>/dev/null || true; } | wc -l | tr -d ' ')
assert "project files NOT backed up" "[ '$PROJECT_BACKUP_HITS' = '0' ]"

rm -rf "$TMP"

# ---------------------------------------------------------------------------
echo "=== known-projects-update ==="
# section: known-projects-update — registry path gets rewritten on apply
TMP=$(mktmpdir)
FAKE_HOME="$TMP/home"
FAKE_REPO="$TMP/repo"
OLD="/Users/y/Sites/localhost/$OLD"
NEW="/Users/y/Sites/localhost/$NEW"

mkdir -p "$FAKE_HOME/.claude" "$FAKE_REPO"
cat > "$FAKE_HOME/.claude/known-projects.json" <<JSON
{"projects":[{"name":"school-activities-hub","path":"$OLD","first_seen":"2026-05-20","last_seen":"2026-05-23"}]}
JSON
# Add at least one matching file so apply has work to do.
echo "path: $OLD" > "$FAKE_HOME/.claude/CLAUDE.md"

"$CORE" apply "$OLD" "$NEW" --repo "$FAKE_REPO" --home "$FAKE_HOME" >/dev/null

REG="$FAKE_HOME/.claude/known-projects.json"
NEW_IN_REG=$(grep -cF "$NEW" "$REG")
OLD_IN_REG=$(grep -cF "$OLD" "$REG" || true)
assert "registry path rewritten to NEW" "[ '$NEW_IN_REG' -ge '1' ]"
assert "registry no longer contains OLD path" "[ '$OLD_IN_REG' = '0' ]"

rm -rf "$TMP"

# ---------------------------------------------------------------------------
echo "=== hook-rename ==="
# section: hook-rename — old path gone → hook emits warning JSON
TMP=$(mktmpdir)
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"
cat > "$FAKE_HOME/.claude/known-projects.json" <<JSON
{"projects":[{"name":"naschool","path":"$TMP/ghost-path","first_seen":"2026-05-20","last_seen":"2026-05-23"}]}
JSON
mkdir -p "$TMP/Sites/naschool"
# Run hook with new $PWD = $TMP/Sites/naschool (same basename, different path,
# and old path $TMP/ghost-path does NOT exist).
HOOK_OUT=$(cd "$TMP/Sites/naschool" && HOME="$FAKE_HOME" bash "$HOOK" </dev/null)
assert "hook emits warning JSON when old path gone" "echo '$HOOK_OUT' | grep -q 'Possible repo rename detected'"
assert "hook output is valid JSON envelope" "echo '$HOOK_OUT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"SessionStart\"'"
rm -rf "$TMP"

# ---------------------------------------------------------------------------
echo "=== multi-clone-guard ==="
# section: multi-clone — both paths exist → hook emits NO warning
TMP=$(mktmpdir)
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"
mkdir -p "$TMP/clone-a/naschool" "$TMP/clone-b/naschool"
cat > "$FAKE_HOME/.claude/known-projects.json" <<JSON
{"projects":[{"name":"naschool","path":"$TMP/clone-a/naschool","first_seen":"2026-05-20","last_seen":"2026-05-23"}]}
JSON
# Run hook in clone-b — same basename, different path, BUT clone-a still exists.
HOOK_OUT=$(cd "$TMP/clone-b/naschool" && HOME="$FAKE_HOME" bash "$HOOK" </dev/null)
assert "hook stays silent when multi-clone" "[ -z '$HOOK_OUT' ]"
# Registry should have appended a second disambiguated entry.
SECOND_ENTRY=$(python3 -c "import json; d=json.load(open('$FAKE_HOME/.claude/known-projects.json')); print(len(d['projects']))")
assert "registry has 2 entries (multi-clone tracked)" "[ '$SECOND_ENTRY' = '2' ]"
rm -rf "$TMP"

# ---------------------------------------------------------------------------
echo "=== installer-idempotent ==="
# section: installer wires SessionStart hook + is idempotent
TMP=$(mktmpdir)
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"

# First install.
HOME="$FAKE_HOME" bash "$INSTALLER" >/dev/null
WIRED_COUNT=$(python3 -c "
import json
d=json.load(open('$FAKE_HOME/.claude/settings.json'))
sess=d.get('hooks',{}).get('SessionStart',[])
n=sum(1 for b in sess for h in b.get('hooks',[]) if 'rename-detector' in h.get('command',''))
print(n)
")
assert "first install wires 1 SessionStart entry" "[ '$WIRED_COUNT' = '1' ]"

# Second install — must be a no-op.
HOME="$FAKE_HOME" bash "$INSTALLER" >/dev/null
WIRED_COUNT=$(python3 -c "
import json
d=json.load(open('$FAKE_HOME/.claude/settings.json'))
sess=d.get('hooks',{}).get('SessionStart',[])
n=sum(1 for b in sess for h in b.get('hooks',[]) if 'rename-detector' in h.get('command',''))
print(n)
")
assert "second install is idempotent (still 1 entry)" "[ '$WIRED_COUNT' = '1' ]"

# Registry seeded.
assert "installer seeded known-projects.json" "[ -f '$FAKE_HOME/.claude/known-projects.json' ]"
assert "hook copied to ~/.claude/hooks/" "[ -x '$FAKE_HOME/.claude/hooks/rename-detector.sh' ]"

# Refuse to clobber malformed JSON.
echo 'not valid json at all { { {' > "$FAKE_HOME/.claude/settings.json"
set +e
CORRUPT_OUT=$(HOME="$FAKE_HOME" bash "$INSTALLER" 2>&1)
CORRUPT_EXIT=$?
set -e
assert "installer refuses malformed settings.json (exit non-zero)" "[ '$CORRUPT_EXIT' -ne 0 ]"
assert "installer surfaces refusal reason"  "echo '$CORRUPT_OUT' | grep -qi 'malformed'"
# Reset for the uninstall test below.
echo '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash \"'"$FAKE_HOME"'/.claude/hooks/rename-detector.sh\""}]}]}}' > "$FAKE_HOME/.claude/settings.json"

# Uninstall removes everything.
HOME="$FAKE_HOME" bash "$INSTALLER" --uninstall >/dev/null
WIRED_COUNT=$(python3 -c "
import json
d=json.load(open('$FAKE_HOME/.claude/settings.json'))
sess=d.get('hooks',{}).get('SessionStart',[])
n=sum(1 for b in sess for h in b.get('hooks',[]) if 'rename-detector' in h.get('command',''))
print(n)
")
assert "uninstall removes SessionStart entry" "[ '$WIRED_COUNT' = '0' ]"
assert "uninstall removes hook script" "[ ! -e '$FAKE_HOME/.claude/hooks/rename-detector.sh' ]"

rm -rf "$TMP"

print_summary_and_exit
