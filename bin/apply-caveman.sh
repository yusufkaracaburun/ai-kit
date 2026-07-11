#!/usr/bin/env bash
# Install and activate the caveman companion (token-compressed output mode).
#
# caveman is third-party (JuliusBrussee/caveman). ai-kit never vendors it —
# this script drives the official Claude Code plugin CLI and writes caveman's
# own config file. Nothing is copied into ai-kit.
#
# Three steps, each idempotent:
#
#   1. Marketplace  — `claude plugin marketplace add JuliusBrussee/caveman`
#                     (skipped when already in ~/.claude/settings.json
#                     extraKnownMarketplaces).
#   2. Install      — `claude plugin install caveman@caveman --scope user`
#                     (skipped when already true in enabledPlugins).
#   3. Activate     — write {"defaultMode": "full"} into caveman's config
#                     (${XDG_CONFIG_HOME:-~/.config}/caveman/config.json),
#                     merged, never clobbering other keys. Without this the
#                     mode resolves to caveman's own 'full' fallback, which
#                     works but is implicit — we make it explicit and durable.
#
# Plus a de-duplication guard. caveman's own installer (`bin/install.js
# --with-hooks`) copies its hooks into ~/.claude/hooks/ AND writes them into
# ~/.claude/settings.json — but the plugin manifest ALREADY declares the same
# SessionStart + UserPromptSubmit hooks. A machine that ran both ends up
# firing every caveman hook twice per event. We detect that and strip the
# standalone copies, leaving the plugin's own declaration as the single source.
#
# MACHINE-WIDE. This changes how the agent responds in every project on this
# machine, not just the target one. /ai:setup asks before calling this.
#
# Usage:
#   apply-caveman.sh                 install + activate + de-duplicate
#   apply-caveman.sh --status        report state, change nothing
#   apply-caveman.sh --dedupe-only   only strip duplicate hooks
#   apply-caveman.sh --uninstall     disable the plugin, set defaultMode=off
#   apply-caveman.sh --mode <mode>   activate with a mode other than 'full'
set -euo pipefail

MARKETPLACE="JuliusBrussee/caveman"
PLUGIN="caveman@caveman"
SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caveman"
CONFIG="$CONFIG_DIR/config.json"
MODE="full"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --status) ACTION="status"; shift ;;
    --dedupe-only) ACTION="dedupe"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --mode) MODE="${2:?--mode needs a value}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    -h | --help) sed -n '2,36p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required" >&2
  exit 1
}

# --- state -------------------------------------------------------------------
read_state() {
  python3 - "$SETTINGS" "$PLUGIN" <<'PY'
import json, os, sys
path, plugin = sys.argv[1], sys.argv[2]
data = {}
if os.path.isfile(path):
    try:
        with open(path) as f:
            data = json.load(f)
        if not isinstance(data, dict):
            data = {}
    except json.JSONDecodeError:
        print("MALFORMED")
        sys.exit(0)
mkts = data.get("extraKnownMarketplaces") or {}
enabled = data.get("enabledPlugins") or {}
name = plugin.split("@")[0]

dupes = 0
hooks = data.get("hooks") or {}
for event in ("SessionStart", "UserPromptSubmit"):
    for block in hooks.get(event) or []:
        if not isinstance(block, dict):
            continue
        for h in block.get("hooks") or []:
            if isinstance(h, dict) and "caveman-" in h.get("command", ""):
                dupes += 1

print("marketplace=%s" % ("yes" if name in mkts else "no"))
print("installed=%s" % ("yes" if enabled.get(plugin) is True else "no"))
print("dupe_hooks=%d" % dupes)
PY
}

STATE="$(read_state)"
if [ "$STATE" = "MALFORMED" ]; then
  echo "error: $SETTINGS is not valid JSON — refusing to touch it" >&2
  exit 1
fi
HAS_MARKETPLACE="$(sed -n 's/^marketplace=//p' <<<"$STATE")"
IS_INSTALLED="$(sed -n 's/^installed=//p' <<<"$STATE")"
DUPE_HOOKS="$(sed -n 's/^dupe_hooks=//p' <<<"$STATE")"

CURRENT_MODE="(unset — falls back to caveman's built-in 'full')"
[ -f "$CONFIG" ] && CURRENT_MODE="$(python3 -c "
import json,sys
try:
    print(json.load(open('$CONFIG')).get('defaultMode') or '(unset)')
except Exception:
    print('(unreadable)')
")"

# --- backup ------------------------------------------------------------------
backup_settings() {
  [ -f "$SETTINGS" ] || return 0
  local dir="$HOME/.claude/.backups/$(date -u +"%Y%m%dT%H%M%SZ")"
  mkdir -p "$dir"
  cp "$SETTINGS" "$dir/settings.json"
  echo "  backup: $dir/settings.json"
}

# --- de-duplicate ------------------------------------------------------------
# Strip the standalone caveman hook entries from ~/.claude/settings.json. Safe
# only because the plugin manifest declares the same hooks — verified before
# removal, so a machine that has the standalone hooks WITHOUT the plugin keeps
# working.
dedupe_hooks() {
  if [ "$DUPE_HOOKS" -eq 0 ]; then
    echo "  no duplicate caveman hooks in $SETTINGS"
    return 0
  fi
  if [ "$IS_INSTALLED" != "yes" ]; then
    echo "  ! $DUPE_HOOKS standalone caveman hook(s) found, but the plugin is not enabled."
    echo "    Leaving them alone — removing them would disable caveman entirely."
    return 0
  fi
  backup_settings
  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

def is_caveman(block):
    return any(
        isinstance(h, dict) and "caveman-" in h.get("command", "")
        for h in block.get("hooks", [])
    ) if isinstance(block, dict) else False

hooks = data.get("hooks") or {}
removed = 0
for event in ("SessionStart", "UserPromptSubmit"):
    before = hooks.get(event) or []
    after = [b for b in before if not is_caveman(b)]
    removed += len(before) - len(after)
    if after:
        hooks[event] = after
    else:
        hooks.pop(event, None)

if hooks:
    data["hooks"] = hooks
else:
    data.pop("hooks", None)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"  removed {removed} duplicate caveman hook entr{'y' if removed == 1 else 'ies'}")
print("  (the plugin manifest still declares them — caveman keeps working)")
PY
}

# --- activate ----------------------------------------------------------------
write_mode() {
  local mode="$1"
  mkdir -p "$CONFIG_DIR"
  [ -f "$CONFIG" ] || echo '{}' > "$CONFIG"
  python3 - "$CONFIG" "$mode" <<'PY'
import json, sys
path, mode = sys.argv[1], sys.argv[2]
VALID = {"off", "lite", "full", "ultra",
         "wenyan-lite", "wenyan", "wenyan-full", "wenyan-ultra",
         "commit", "review", "compress"}
if mode not in VALID:
    print(f"error: invalid mode {mode!r} (expected one of {sorted(VALID)})", file=sys.stderr)
    sys.exit(2)
try:
    with open(path) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
if data.get("defaultMode") == mode:
    print(f"  defaultMode already {mode!r}; config unchanged")
    sys.exit(0)
data["defaultMode"] = mode
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"  defaultMode = {mode!r} -> {path}")
PY
}

# --- actions -----------------------------------------------------------------
case "$ACTION" in
  status)
    echo "caveman status"
    echo "  marketplace known : $HAS_MARKETPLACE ($MARKETPLACE)"
    echo "  plugin enabled    : $IS_INSTALLED ($PLUGIN)"
    echo "  default mode      : $CURRENT_MODE"
    echo "  duplicate hooks   : $DUPE_HOOKS $([ "$DUPE_HOOKS" -gt 0 ] && echo '(run --dedupe-only)')"
    exit 0
    ;;

  dedupe)
    echo "caveman: de-duplicating hooks"
    dedupe_hooks
    exit 0
    ;;

  uninstall)
    echo "caveman: uninstalling"
    if [ "$IS_INSTALLED" = "yes" ]; then
      claude plugin disable "$PLUGIN" || echo "  ! 'claude plugin disable' failed — disable it via /plugin"
    else
      echo "  plugin not enabled; nothing to disable"
    fi
    [ -f "$CONFIG" ] && write_mode off
    echo "caveman uninstalled. Restart the session for it to take effect."
    exit 0
    ;;

  install)
    echo "caveman: install + activate (machine-wide)"

    command -v claude >/dev/null 2>&1 || {
      echo "error: the 'claude' CLI is not on PATH — cannot install the plugin" >&2
      echo "       Install by hand: /plugin marketplace add $MARKETPLACE" >&2
      echo "                        /plugin install $PLUGIN" >&2
      exit 1
    }

    if [ "$HAS_MARKETPLACE" = "yes" ]; then
      echo "  marketplace already known: $MARKETPLACE"
    else
      echo "  adding marketplace $MARKETPLACE"
      claude plugin marketplace add "$MARKETPLACE" --scope user
    fi

    if [ "$IS_INSTALLED" = "yes" ]; then
      echo "  plugin already enabled: $PLUGIN"
    else
      echo "  installing $PLUGIN"
      claude plugin install "$PLUGIN" --scope user
    fi

    write_mode "$MODE"

    # Re-read: a fresh install may have added standalone hooks.
    STATE="$(read_state)"
    IS_INSTALLED="$(sed -n 's/^installed=//p' <<<"$STATE")"
    DUPE_HOOKS="$(sed -n 's/^dupe_hooks=//p' <<<"$STATE")"
    dedupe_hooks

    echo
    echo "caveman active at mode '$MODE' from the next session."
    echo "  switch: /caveman lite|full|ultra   ·   off: 'stop caveman' or apply-caveman.sh --uninstall"
    echo "  NOTE: this affects every project on this machine, not just this one."
    ;;
esac
