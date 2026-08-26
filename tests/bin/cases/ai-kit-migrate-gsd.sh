#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# ai-kit-migrate-gsd.sh detects + (with --apply) removes the legacy gsd
# footprint from ~/.claude, an optional --project dir, and settings.json.
# Every case here runs with HOME redirected into a temp dir, so the
# developer's real machine is never touched.
#
# NOT COVERED: the interactive "Keep a backup?" prompt — that only fires on
# a tty ([ -t 0 ]) and simulating one would need a pty harness. What IS
# covered is the non-tty default it falls back to (backup), explicit
# --backup / --no-backup / --backup-dir, detection + reporting, the
# settings.json hook/statusLine patch, --project scanning (including the
# outside-$HOME backup path), arg validation, and idempotency.

migrate() {
  # migrate <sandbox_home> [args...]
  local home="$1"; shift
  HOME="$home" bash "$AIKIT/bin/ai-kit-migrate-gsd.sh" "$@" </dev/null
}

seed_footprint() {
  # seed_footprint <sandbox_home>
  local home="$1"
  mkdir -p "$home/.claude/get-shit-done"
  echo '{}' > "$home/.claude/gsd-file-manifest.json"
  mkdir -p "$home/.claude/skills/gsd-plan"
  touch "$home/.claude/skills/gsd-plan/SKILL.md"
}

seed_settings_with_gsd_hooks() {
  # seed_settings_with_gsd_hooks <sandbox_home>
  local home="$1"
  mkdir -p "$home/.claude"
  python3 - "$home/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
data = {
    "hooks": {
        "SessionStart": [
            {"hooks": [{"type": "command", "command": "node ~/.claude/get-shit-done/hooks/gsd-activate.js"}]},
            {"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/unrelated.sh"}]},
        ],
    },
    "statusLine": {"type": "command", "command": "bash ~/.claude/get-shit-done/gsd-statusline.sh"},
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
}

echo "=== detect: clean home ==="
H=$(mktemp -d)
OUT=$(migrate "$H")
assert "clean home reports nothing detected" 'grep -q "nothing detected" <<<"$OUT"'
RC=0; migrate "$H" >/dev/null || RC=$?
assert "clean scan exits 0" '[ "$RC" -eq 0 ]'
rm -rf "$H"

echo "=== detect: footprint present, dry-run ==="
H=$(mktemp -d)
seed_footprint "$H"
OUT=$(migrate "$H")
assert "dry-run lists the gsd install dir" 'grep -q "get-shit-done/" <<<"$OUT"'
assert "dry-run lists the gsd manifest file" 'grep -q "gsd-file-manifest.json" <<<"$OUT"'
assert "dry-run lists the gsd-* skill dir" 'grep -q "skills/gsd-plan" <<<"$OUT"'
assert "dry-run tells the user to pass --apply" 'grep -q "Pass --apply" <<<"$OUT"'
assert "dry-run removes nothing" '[ -d "$H/.claude/get-shit-done" ]'
rm -rf "$H"

echo "=== apply --no-backup: removes, irreversibly ==="
H=$(mktemp -d)
seed_footprint "$H"
OUT=$(migrate "$H" --apply --no-backup)
assert "reports the removal" 'grep -q "removed: $H/.claude/get-shit-done" <<<"$OUT"'
assert "install dir gone" '[ ! -d "$H/.claude/get-shit-done" ]'
assert "manifest file gone" '[ ! -f "$H/.claude/gsd-file-manifest.json" ]'
assert "no backup dir created" '[ ! -d "$H/.cache/ai-kit" ]'
assert "output says backup was skipped" 'grep -q "SKIPPED" <<<"$OUT"'
OUT2=$(migrate "$H")
assert "second scan is clean (idempotent)" 'grep -q "nothing detected" <<<"$OUT2"'
rm -rf "$H"

echo "=== apply with no explicit backup flag: non-tty defaults to backup ==="
H=$(mktemp -d)
seed_footprint "$H"
OUT=$(migrate "$H" --apply)
assert "default (non-tty) path takes a backup" 'grep -qE "^Backup: $H/.cache/ai-kit/migrate-gsd-" <<<"$OUT"'
BACKUP_DIR=$(sed -n 's/^Backup: //p' <<<"$OUT" | head -1)
assert "backup captured the removed install dir" '[ -d "$BACKUP_DIR/.claude/get-shit-done" ]'
assert "backup captured the removed manifest file" '[ -f "$BACKUP_DIR/.claude/gsd-file-manifest.json" ]'
assert "original install dir removed" '[ ! -d "$H/.claude/get-shit-done" ]'
rm -rf "$H"

echo "=== --project scanning: custom --backup-dir, outside-\$HOME path ==="
H=$(mktemp -d)
PROJ=$(mktemp -d)
mkdir -p "$PROJ/.claude/skills/gsd-old"
touch "$PROJ/.claude/skills/gsd-old/SKILL.md"
CUSTOM="$H/custom-backup"
OUT=$(migrate "$H" --project "$PROJ" --apply --backup-dir "$CUSTOM")
assert "custom backup dir is used" 'grep -q "Backup: $CUSTOM" <<<"$OUT"'
assert "outside-\$HOME artifact backed up under absolute/" '[ -d "$CUSTOM/absolute$PROJ/.claude/skills/gsd-old" ]'
assert "project artifact removed" '[ ! -d "$PROJ/.claude/skills/gsd-old" ]'
rm -rf "$H" "$PROJ"

echo "=== settings.json patch: strips gsd hooks + statusLine, keeps unrelated hook ==="
H=$(mktemp -d)
seed_settings_with_gsd_hooks "$H"
OUT=$(migrate "$H" --apply --backup)
assert "detects settings needing a patch" 'grep -q "hook reference(s)" <<<"$OUT"'
assert "reports settings patched" 'grep -q "patched: $H/.claude/settings.json" <<<"$OUT"'
assert "gsd hook stripped, unrelated hook kept, statusLine dropped" \
  'python3 -c "
import json
d = json.load(open(\"$H/.claude/settings.json\"))
hooks = d.get(\"hooks\", {})
cmds = [h[\"command\"] for e in hooks.get(\"SessionStart\", []) for h in e[\"hooks\"]]
assert not any(\"gsd-\" in c for c in cmds), cmds
assert any(\"unrelated.sh\" in c for c in cmds), cmds
assert \"statusLine\" not in d, d
"'
assert "settings.json backed up before patch" '[ -f "$H"/.cache/ai-kit/migrate-gsd-*/settings.json.bak ]'
rm -rf "$H"

echo "=== arg validation ==="
H=$(mktemp -d)
RC=0; ERR=$(migrate "$H" --bogus 2>&1) || RC=$?
assert "unknown arg is rejected" '[ "$RC" -eq 2 ]'
assert "error names the bad arg" 'grep -q "Unknown arg: --bogus" <<<"$ERR"'

RC=0; ERR=$(migrate "$H" --project /no/such/path 2>&1) || RC=$?
assert "nonexistent --project path is rejected" '[ "$RC" -eq 2 ]'
assert "error names the missing project path" 'grep -q "Project path does not exist" <<<"$ERR"'

OUT=$(migrate "$H" --help)
RC=0; migrate "$H" --help >/dev/null || RC=$?
assert "help text describes usage" 'grep -q "USAGE:" <<<"$OUT"'
assert "help exits 0" '[ "$RC" -eq 0 ]'
rm -rf "$H"

print_summary_and_exit
