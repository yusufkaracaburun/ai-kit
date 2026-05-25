#!/usr/bin/env bash
# Mechanical core for /ai:rename-housekeeping.
#
# The skill orchestrates user interaction (preview confirmation, etc.) and
# delegates the deterministic file-work to this script so it is testable
# without an LLM in the loop.
#
# Usage:
#   rename-housekeeping-core.sh scan  <old> <new> [--repo <path>] [--home <path>]
#   rename-housekeeping-core.sh apply <old> <new> [--repo <path>] [--home <path>]
#
# Modes:
#   scan  — emit one match per line: "<file>\t<line>\t<full-line>". Exit 0 if
#           hits found, exit 1 if none. Never modifies anything.
#   apply — backup user-global targets to ~/.claude/.backups/<ts>/, then
#           replace every literal occurrence of <old> with <new> across the
#           detector universe. Update known-projects.json. Print summary.
#
# Flags:
#   --repo <path>  override repo root (default: $(pwd))
#   --home <path>  override $HOME (used by tests against a fake home dir)
#
# Detector universe (literal scan, not regex):
#   ~/.claude/CLAUDE.md
#   ~/.claude/*.md
#   ~/.claude/rules/**/*.md
#   ~/.claude/projects/*/memory/**/*.md
#   <repo>/CLAUDE.md
#   <repo>/AGENTS.md
#   <repo>/.agents/memory/**/*.md
#   <repo>/.planning/**/*.md
#   <repo>/docs/**/*.md
#   <repo>/.claude/**/*.md
#   ~/.cursor/**/*.md  (if dir exists)
#   ~/.codex/**/*.md   (if dir exists)
#   ~/.gemini/**/*.md  (if dir exists)
#
# Skipped: paths under node_modules/, vendor/, .git/, files > 1 MB.
#
# Backup policy: every file under $HOME/.claude/** that will be modified is
# copied to $HOME/.claude/.backups/<YYYYMMDDTHHMMSSZ>/<sanitised-relative-path>
# BEFORE the in-place replace. Project-local files are not backed up — the
# user's VCS (git) is the safety net there.

set -euo pipefail

MODE="${1:-}"
OLD="${2:-}"
NEW="${3:-}"
shift 3 2>/dev/null || true

REPO="$(pwd)"
HOME_DIR="$HOME"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --home) HOME_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$MODE" ] || [ -z "$OLD" ] || [ -z "$NEW" ]; then
  cat >&2 <<EOF
Usage:
  $(basename "$0") scan  <old> <new> [--repo <path>] [--home <path>]
  $(basename "$0") apply <old> <new> [--repo <path>] [--home <path>]
EOF
  exit 2
fi

if [ "$OLD" = "$NEW" ]; then
  echo "old == new; nothing to do" >&2
  exit 2
fi

build_target_list() {
  # Emit one absolute file path per line. De-dupe at the end.
  local h="$HOME_DIR"
  local r="$REPO"

  # User-global
  [ -f "$h/.claude/CLAUDE.md" ] && echo "$h/.claude/CLAUDE.md"
  if [ -d "$h/.claude" ]; then
    find "$h/.claude" -maxdepth 1 -type f -name '*.md' 2>/dev/null
  fi
  if [ -d "$h/.claude/rules" ]; then
    find "$h/.claude/rules" -type f -name '*.md' 2>/dev/null
  fi
  if [ -d "$h/.claude/projects" ]; then
    find "$h/.claude/projects" -type d -name memory \
      -exec find {} -type f -name '*.md' \; 2>/dev/null
  fi

  # Project root
  [ -f "$r/CLAUDE.md" ] && echo "$r/CLAUDE.md"
  [ -f "$r/AGENTS.md" ] && echo "$r/AGENTS.md"
  for sub in .agents/memory .planning docs .claude; do
    if [ -d "$r/$sub" ]; then
      find "$r/$sub" -type f -name '*.md' \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/.git/*' 2>/dev/null
    fi
  done

  # Cross-agent
  for agent in cursor codex gemini; do
    if [ -d "$h/.$agent" ]; then
      find "$h/.$agent" -type f -name '*.md' \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' 2>/dev/null
    fi
  done
}

emit_targets() {
  build_target_list | awk '!seen[$0]++'
}

scan_hits() {
  # Print "<file>\t<lineno>\t<line>" for every literal match.
  # Skip files >1MB (size check) and unreadable files.
  local f size
  while IFS= read -r f; do
    [ -r "$f" ] || continue
    size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
    [ -z "$size" ] && continue
    [ "$size" -gt 1048576 ] && continue
    grep -nF -- "$OLD" "$f" 2>/dev/null | while IFS= read -r match; do
      # match looks like: "12:some content"
      printf "%s\t%s\n" "$f" "$match"
    done
  done < <(emit_targets)
}

case "$MODE" in
  scan)
    HITS="$(scan_hits || true)"
    if [ -z "$HITS" ]; then
      exit 1
    fi
    echo "$HITS"
    ;;

  apply)
    TS="$(date -u +%Y%m%dT%H%M%SZ)"
    BACKUP_ROOT="$HOME_DIR/.claude/.backups/$TS"
    MODIFIED=0
    BACKED_UP=0

    # Collect unique target files with at least one hit.
    HITS="$(scan_hits || true)"
    if [ -z "$HITS" ]; then
      echo "modified: 0 files, 0 replacements"
      echo "backups : (none)"
      exit 0
    fi

    # Unique file list from hits.
    FILES=$(printf "%s\n" "$HITS" | awk -F'\t' '{print $1}' | awk '!seen[$0]++')

    while IFS= read -r f; do
      [ -z "$f" ] && continue
      # Backup if under $HOME_DIR/.claude/ (literal prefix check).
      case "$f" in
        "$HOME_DIR/.claude/"*)
          rel="${f#"$HOME_DIR/.claude/"}"
          # Sanitise: replace '/' with '__' for flat layout under backup dir.
          # (We could keep nesting; flat is easier to inspect.)
          dest="$BACKUP_ROOT/$(printf "%s" "$rel" | tr '/' '_')"
          mkdir -p "$(dirname "$dest")"
          cp "$f" "$dest"
          BACKED_UP=$((BACKED_UP + 1))
          ;;
      esac

      # In-place literal replace. Use a portable sed approach: a python helper
      # so we don't have to escape regex metachars in $OLD/$NEW.
      python3 - "$f" "$OLD" "$NEW" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(p, "rb") as fh:
    data = fh.read()
try:
    text = data.decode("utf-8")
except UnicodeDecodeError:
    # Binary or odd encoding — skip.
    sys.exit(0)
if old not in text:
    sys.exit(0)
new_text = text.replace(old, new)
with open(p, "wb") as fh:
    fh.write(new_text.encode("utf-8"))
PY
      MODIFIED=$((MODIFIED + 1))
    done <<< "$FILES"

    # Update known-projects.json if it tracks the old path.
    REG="$HOME_DIR/.claude/known-projects.json"
    if [ -f "$REG" ] && command -v python3 >/dev/null 2>&1; then
      python3 - "$REG" "$OLD" "$NEW" <<'PY'
import json, sys, datetime
reg_path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
today = datetime.date.today().isoformat()
try:
    with open(reg_path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
projects = data.get("projects")
if not isinstance(projects, list):
    sys.exit(0)
changed = False
for e in projects:
    if not isinstance(e, dict):
        continue
    p = e.get("path", "")
    if old in p:
        e["path"] = p.replace(old, new)
        e["last_seen"] = today
        changed = True
    # name match (basename rename)
    if e.get("name") == old:
        e["name"] = new
        changed = True
if changed:
    with open(reg_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
    fi

    echo "modified: $MODIFIED files"
    echo "backups : $BACKED_UP files in $BACKUP_ROOT"
    ;;

  *)
    echo "unknown mode: $MODE (use scan|apply)" >&2
    exit 2
    ;;
esac
