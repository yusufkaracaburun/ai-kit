#!/usr/bin/env bash
# Install and activate the ponytail companion (minimal-code discipline).
#
# ponytail is third-party (DietrichGebert/ponytail). ai-kit never vendors it —
# this script drives the official Claude Code plugin CLI and writes ponytail's
# own config file. Nothing is copied into ai-kit.
#
# Three steps, each idempotent:
#
#   1. Marketplace  — `claude plugin marketplace add DietrichGebert/ponytail`
#                     (skipped when already in ~/.claude/settings.json
#                     extraKnownMarketplaces).
#   2. Install      — `claude plugin install ponytail@ponytail --scope user`
#                     (skipped when already true in enabledPlugins).
#   3. Activate     — write {"defaultMode": "full"} into ponytail's config
#                     (${XDG_CONFIG_HOME:-~/.config}/ponytail/config.json),
#                     merged, never clobbering other keys. Without this the
#                     mode resolves to ponytail's own 'full' fallback, which
#                     works but is implicit — we make it explicit and durable.
#
# No de-duplication guard, unlike apply-caveman.sh. ponytail ships no standalone
# installer that copies hooks into ~/.claude/settings.json — the plugin manifest
# (hooks/claude-codex-hooks.json) is the only declaration, so there is nothing
# to double-fire. Verified at 2ed6c52.
#
# MACHINE-WIDE. This changes how the agent writes code in every project on this
# machine, not just the target one. /ai:setup asks before calling this.
#
# Usage:
#   apply-ponytail.sh                 install + activate
#   apply-ponytail.sh --status        report state, change nothing
#   apply-ponytail.sh --uninstall     disable the plugin, set defaultMode=off
#   apply-ponytail.sh --mode <mode>   activate with a mode other than 'full'
set -euo pipefail

MARKETPLACE="DietrichGebert/ponytail"
PLUGIN="ponytail@ponytail"
SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ponytail"
CONFIG="$CONFIG_DIR/config.json"
MODE="full"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --status) ACTION="status"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --mode) MODE="${2:?--mode needs a value}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    -h | --help) sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required" >&2
  exit 1
}

# Validate before the marketplace add and install run, not after: an invalid
# --mode used to install the plugin and only then exit 2.
case "$MODE" in
  off | lite | full | ultra) ;;
  *) echo "error: invalid mode '$MODE' (expected: off, lite, full, ultra)" >&2; exit 2 ;;
esac

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

print("marketplace=%s" % ("yes" if name in mkts else "no"))
print("installed=%s" % ("yes" if enabled.get(plugin) is True else "no"))
PY
}

STATE="$(read_state)"
if [ "$STATE" = "MALFORMED" ]; then
  echo "error: $SETTINGS is not valid JSON — refusing to touch it" >&2
  exit 1
fi
HAS_MARKETPLACE="$(sed -n 's/^marketplace=//p' <<<"$STATE")"
IS_INSTALLED="$(sed -n 's/^installed=//p' <<<"$STATE")"

CURRENT_MODE="(unset — falls back to ponytail's built-in 'full')"
# Path goes through argv, never interpolated into the source: a quote in $HOME
# or $XDG_CONFIG_HOME would otherwise break out of the string literal.
[ -f "$CONFIG" ] && CURRENT_MODE="$(python3 - "$CONFIG" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("defaultMode") or "(unset)")
except Exception:
    print("(unreadable)")
PY
)"

# --- activate ----------------------------------------------------------------
write_mode() {
  local mode="$1"
  mkdir -p "$CONFIG_DIR"
  [ -f "$CONFIG" ] || echo '{}' > "$CONFIG"
  python3 - "$CONFIG" "$mode" <<'PY'
import json, sys
path, mode = sys.argv[1], sys.argv[2]
# ponytail's own RUNTIME_MODES (hooks/ponytail-config.js). 'review' is a runtime
# command mode only — it is deliberately not persistable as a default.
VALID = {"off", "lite", "full", "ultra"}
if mode not in VALID:
    print(f"error: invalid mode {mode!r} (expected one of {sorted(VALID)})", file=sys.stderr)
    sys.exit(2)
try:
    with open(path) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("top-level JSON is not an object")
except FileNotFoundError:
    data = {}
except (json.JSONDecodeError, ValueError) as exc:
    # Refuse rather than silently reset: this file is ponytail's, and it may
    # carry keys we do not own (hideStatus, quietStartup). Same posture as the
    # hard refuse on a malformed ~/.claude/settings.json.
    print(f"error: {path} is not valid JSON ({exc}) — refusing to overwrite it",
          file=sys.stderr)
    print("       Fix or delete the file, then re-run.", file=sys.stderr)
    sys.exit(1)
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
    echo "ponytail status"
    echo "  marketplace known : $HAS_MARKETPLACE ($MARKETPLACE)"
    echo "  plugin enabled    : $IS_INSTALLED ($PLUGIN)"
    echo "  default mode      : $CURRENT_MODE"
    exit 0
    ;;

  uninstall)
    echo "ponytail: uninstalling"
    if [ "$IS_INSTALLED" = "yes" ]; then
      claude plugin disable "$PLUGIN" || echo "  ! 'claude plugin disable' failed — disable it via /plugin"
    else
      echo "  plugin not enabled; nothing to disable"
    fi
    [ -f "$CONFIG" ] && write_mode off
    echo "ponytail uninstalled. Restart the session for it to take effect."
    exit 0
    ;;

  install)
    echo "ponytail: install + activate (machine-wide)"

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

    echo
    echo "ponytail active at mode '$MODE' from the next session."
    echo "  switch: /ponytail lite|full|ultra   ·   off: /ponytail off or apply-ponytail.sh --uninstall"
    echo "  NOTE: this affects every project on this machine, not just this one."
    ;;
esac
