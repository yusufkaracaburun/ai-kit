#!/usr/bin/env bash
# ai-kit-migrate-gsd.sh — detect + optionally remove the legacy
# "get-shit-done" (gsd) install footprint from ~/.claude and an optional
# project directory.
#
# WHY: ai-kit's predecessor — "gsd" — installed itself under ~/.claude/
# (binaries, subagents, SessionStart hooks, statusline, metadata files).
# When you install ai-kit on top, the gsd artifacts silently co-exist:
# Claude Code still loads the gsd SessionStart hook, which surfaces every
# gsd-* skill in the available-skills list, so chats keep routing to
# /gsd-* even though /ai:* is what you wanted.
#
# This tool detects the footprint and (with --apply) removes it. Every
# removal is backed up first under ~/.cache/ai-kit/migrate-gsd-<ts>/.
#
# USAGE:
#   ai-kit-migrate-gsd.sh                       # dry-run, scan ~/.claude
#   ai-kit-migrate-gsd.sh --project PATH        # also scan PATH/.claude + PATH/.cursor
#   ai-kit-migrate-gsd.sh --apply               # interactive: asks backup-or-delete
#   ai-kit-migrate-gsd.sh --apply --backup [--backup-dir DIR]
#   ai-kit-migrate-gsd.sh --apply --no-backup   # delete without backup (irreversible)
#
# When --apply runs on a tty without --backup/--no-backup, it prompts:
# "Keep a backup before removing? [Y/n]". Default is Y (safe). With no tty
# (CI, pipe), defaults to backup unless --no-backup is given.
#
set -euo pipefail

PROJECT=""
APPLY=false
BACKUP_MODE="ask"   # ask | backup | no-backup
BACKUP_DIR=""

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed -E 's/^# ?//' | sed '$d'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --apply) APPLY=true; shift ;;
    --backup) BACKUP_MODE="backup"; shift ;;
    --no-backup) BACKUP_MODE="no-backup"; shift ;;
    --backup-dir) BACKUP_MODE="backup"; BACKUP_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

CLAUDE_HOME="${HOME}/.claude"

# Detect — accumulate paths into FOUND_FILES / FOUND_DIRS. Use the
# `${arr[@]+...}` safe-expansion pattern throughout: macOS bash 3.2 errors
# on `${arr[@]}` when arr is an empty array under `set -u`.
FOUND_FILES=()
FOUND_DIRS=()

add_path() {
  if [ -d "$1" ] && [ ! -L "$1" ]; then
    FOUND_DIRS+=("$1")
  elif [ -e "$1" ] || [ -L "$1" ]; then
    FOUND_FILES+=("$1")
  fi
}

# Top-level metadata + install dir.
for path in \
  "$CLAUDE_HOME/get-shit-done" \
  "$CLAUDE_HOME/gsd-file-manifest.json" \
  "$CLAUDE_HOME/gsd-install-state.json" \
  "$CLAUDE_HOME/.gsd-profile" \
  "$CLAUDE_HOME/gsd-migration-journal" \
; do
  add_path "$path"
done

# Subagents, hooks, commands, skills under ~/.claude.
for sub in agents hooks commands skills; do
  base="$CLAUDE_HOME/$sub"
  [ -d "$base" ] || continue
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    add_path "$p"
  done < <(find "$base" -maxdepth 2 -iname "gsd-*" 2>/dev/null || true)
done

# settings.json — detect gsd-referencing hook entries.
SETTINGS="$CLAUDE_HOME/settings.json"
SETTINGS_NEEDS_PATCH=0
if [ -f "$SETTINGS" ] && grep -q "gsd-" "$SETTINGS"; then
  SETTINGS_NEEDS_PATCH=1
fi

# Project-level (.claude and .cursor) if --project given.
if [ -n "$PROJECT" ]; then
  if [ ! -d "$PROJECT" ]; then
    echo "Project path does not exist: $PROJECT" >&2
    exit 2
  fi
  for sub in .claude/skills .claude/commands .claude/agents .claude/hooks .cursor/skills .cursor/commands; do
    base="$PROJECT/$sub"
    [ -d "$base" ] || continue
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      add_path "$p"
    done < <(find "$base" -maxdepth 2 -iname "gsd-*" 2>/dev/null || true)
  done
fi

# Report.
total_artifacts=$(( ${#FOUND_FILES[@]} + ${#FOUND_DIRS[@]} ))
echo "ai-kit-migrate-gsd — scanning gsd legacy footprint"
echo ""
if [ "$total_artifacts" -eq 0 ] && [ "$SETTINGS_NEEDS_PATCH" -eq 0 ]; then
  echo "  (nothing detected — no migration needed)"
  exit 0
fi

if [ "${#FOUND_FILES[@]}" -gt 0 ]; then
  echo "Files / symlinks (${#FOUND_FILES[@]}):"
  for f in ${FOUND_FILES[@]+"${FOUND_FILES[@]}"}; do echo "  - $f"; done
  echo ""
fi
if [ "${#FOUND_DIRS[@]}" -gt 0 ]; then
  echo "Directories (${#FOUND_DIRS[@]}):"
  for d in ${FOUND_DIRS[@]+"${FOUND_DIRS[@]}"}; do echo "  - $d/"; done
  echo ""
fi
if [ "$SETTINGS_NEEDS_PATCH" -eq 1 ]; then
  echo "Settings: $SETTINGS contains gsd-* hook reference(s)."
  echo "  → will remove SessionStart / PostToolUse entries that invoke gsd-* commands."
  echo ""
fi

if [ "$APPLY" = false ]; then
  echo "Dry-run. Pass --apply to actually remove (with backup)."
  exit 0
fi

# Resolve BACKUP_MODE if still "ask".
if [ "$BACKUP_MODE" = "ask" ]; then
  if [ -t 0 ]; then
    printf 'Keep a backup before removing? [Y/n] '
    read -r ANS
    case "$ANS" in
      n|N|no|NO) BACKUP_MODE="no-backup" ;;
      *) BACKUP_MODE="backup" ;;
    esac
  else
    BACKUP_MODE="backup"
  fi
fi

if [ "$BACKUP_MODE" = "backup" ]; then
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$HOME/.cache/ai-kit/migrate-gsd-$(date +%Y%m%dT%H%M%S)"
  fi
  mkdir -p "$BACKUP_DIR"
  echo "Backup: $BACKUP_DIR"
else
  echo "Backup: SKIPPED (--no-backup) — removal is irreversible."
fi
echo ""

backup_then_remove() {
  local path="$1"
  local rel
  rel="${path#$HOME/}"
  if [ "$rel" = "$path" ]; then
    # Outside $HOME — back up under absolute/<path>.
    rel="absolute/$path"
  fi
  if [ "$BACKUP_MODE" = "backup" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -aR "$path" "$BACKUP_DIR/$rel" 2>/dev/null || cp -a "$path" "$BACKUP_DIR/$rel"
  fi
  rm -rf "$path"
  echo "  removed: $path"
}

for f in ${FOUND_FILES[@]+"${FOUND_FILES[@]}"}; do backup_then_remove "$f"; done
for d in ${FOUND_DIRS[@]+"${FOUND_DIRS[@]}"}; do backup_then_remove "$d"; done

# Patch settings.json — drop hook entries whose command references gsd-.
if [ "$SETTINGS_NEEDS_PATCH" -eq 1 ]; then
  if [ "$BACKUP_MODE" = "backup" ]; then
    cp "$SETTINGS" "$BACKUP_DIR/settings.json.bak"
  fi
  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)

def strip_gsd(hooks_block):
    # hooks_block is a list of {matcher?, hooks: [{command:...}]} entries.
    out = []
    for ent in hooks_block:
        sub = ent.get("hooks", [])
        kept = [h for h in sub if "gsd-" not in (h.get("command") or "")]
        if kept:
            ent = dict(ent)
            ent["hooks"] = kept
            out.append(ent)
    return out

hooks = d.get("hooks", {})
new_hooks = {}
for event, entries in hooks.items():
    stripped = strip_gsd(entries)
    if stripped:
        new_hooks[event] = stripped
if new_hooks:
    d["hooks"] = new_hooks
else:
    d.pop("hooks", None)

# Statusline can also reference gsd-* — drop the whole statusLine block if so.
sl = d.get("statusLine") or {}
if "gsd-" in (sl.get("command") or ""):
    d.pop("statusLine", None)

with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
  echo "  patched: $SETTINGS (gsd-* hook + statusLine entries removed)"
fi

echo ""
echo "Done. Restart Claude Code so the new settings.json takes effect."
if [ "$BACKUP_MODE" = "backup" ]; then
  echo "If you need to undo, restore from $BACKUP_DIR."
else
  echo "No backup taken — undo not possible."
fi
