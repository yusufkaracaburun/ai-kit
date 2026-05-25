#!/usr/bin/env bash
# Claude Code SessionStart hook: detect repo-rename + emit "run rename-housekeeping?"
# reminder. Maintains ~/.claude/known-projects.json registry.
#
# Detection logic per project entry {name, path}:
#   - $PWD == known.path                                   → no-op (update last_seen)
#   - basename($PWD) == known.name && $PWD != known.path
#       && ! test -d "known.path"                          → RENAME suspected
#   - basename($PWD) == known.name && $PWD != known.path
#       &&   test -d "known.path"                          → multi-clone (silent, append entry)
#   - new basename                                         → append entry
#
# Output: stdout JSON envelope { "hookSpecificOutput": { "additionalContext": "…" } }
# when a rename is suspected; silent no-op otherwise. Always exits 0 — hook must
# never break a session.
#
# Wire it up with bin/install-rename-hook.sh, or by hand in ~/.claude/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{
#           "type": "command",
#           "command": "bash \"$HOME/.claude/hooks/rename-detector.sh\""
#         }]
#       }]
#     }
#   }

set -uo pipefail

# Read + discard stdin (Claude Code passes session payload; we don't need it).
cat >/dev/null 2>&1 || true

PWD_NOW="$(pwd 2>/dev/null || true)"
[ -z "$PWD_NOW" ] && exit 0

# Multi-clone guard requires python3 for JSON parsing. Bail silently if missing.
command -v python3 >/dev/null 2>&1 || exit 0

REG="${HOME}/.claude/known-projects.json"
mkdir -p "$(dirname "$REG")"
[ -f "$REG" ] || echo '{"projects":[]}' > "$REG"

# Single python3 invocation: read, classify, update, emit.
python3 - "$REG" "$PWD_NOW" <<'PY'
import json, os, sys, datetime

reg_path, pwd_now = sys.argv[1], sys.argv[2]
today = datetime.date.today().isoformat()
basename = os.path.basename(pwd_now.rstrip("/"))
if not basename:
    sys.exit(0)

try:
    with open(reg_path) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {"projects": []}
except (FileNotFoundError, json.JSONDecodeError):
    data = {"projects": []}

projects = data.setdefault("projects", [])
if not isinstance(projects, list):
    projects = data["projects"] = []

rename_old_path = None
matched_known = None

for entry in projects:
    if not isinstance(entry, dict):
        continue
    name, path = entry.get("name"), entry.get("path")
    if not name or not path:
        continue
    if path == pwd_now:
        # Same project, same path — refresh last_seen and exit silently.
        entry["last_seen"] = today
        matched_known = entry
        break
    if name == basename and path != pwd_now:
        # Same basename, different path — rename OR multi-clone.
        if not os.path.isdir(path):
            # Old path gone → rename suspected.
            rename_old_path = path
            matched_known = entry
            break
        # Old path still exists → second clone. Silent: append a second entry
        # under a disambiguating name so the registry stays unique-on-name.
        # We DO NOT mutate the existing entry.
        # Fall through to the append branch below by leaving matched_known None.

if matched_known is None:
    # New project (no name match, or basename clash with surviving clone).
    # Disambiguate by suffixing the path's last two components for clones.
    disambig_name = basename
    if any(
        isinstance(e, dict) and e.get("name") == basename
        for e in projects
    ):
        parent = os.path.basename(os.path.dirname(pwd_now.rstrip("/"))) or "root"
        disambig_name = f"{basename}@{parent}"
    projects.append({
        "name": disambig_name,
        "path": pwd_now,
        "first_seen": today,
        "last_seen": today,
    })

# Persist registry (best-effort; failures stay silent).
try:
    with open(reg_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
except OSError:
    pass

if rename_old_path is None:
    sys.exit(0)

old_name = matched_known.get("name", basename)
msg_lines = [
    "## Possible repo rename detected",
    "",
    f"This directory looks like project **{old_name}**, but its registered",
    f"path differs and the old path no longer exists on disk:",
    "",
    f"- old path : `{rename_old_path}` (gone)",
    f"- new path : `{pwd_now}`",
    "",
    "Stale absolute-path references may still live in memory files",
    "(`~/.claude/CLAUDE.md`, project `CLAUDE.md`, `.agents/memory/**`, etc.).",
    "",
    f"Run `/ai:rename-housekeeping {rename_old_path} {pwd_now}` to scan",
    "and rewrite them, with dry-run preview + backups.",
]
additional = "\n".join(msg_lines) + "\n"

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": additional,
    }
}))
PY

exit 0
