# shellcheck shell=bash
# Plugins surface walk for ai-kit-audit-ecosystem.sh.
# Expects common.sh + dispatcher globals already in scope.

walk_plugins() {
  want_scope plugins || return 0
  [ -f "$INSTALLED_PLUGINS" ] || return 0

  # Emit one TSV row per (plugin, install) tuple, plus a synthetic
  # "__DUP\t<name>\t<count>" row when one plugin name has multiple installs.
  local PLUGIN_ROWS
  PLUGIN_ROWS="$(python3 - "$INSTALLED_PLUGINS" <<'PY'
import json, sys, collections
SEP = "\x1f"
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as exc:
    sys.stderr.write(f"audit: cannot parse {path}: {exc}\n")
    sys.exit(0)
plugins = data.get("plugins", {})
name_count = collections.Counter()
for key, installs in plugins.items():
    base = key.split("@", 1)[0]
    name_count[base] += len(installs or [])
for base, count in name_count.items():
    if count > 1:
        print(f"__DUP{SEP}{base}{SEP}{count}")
for key, installs in plugins.items():
    base, _, marketplace = key.partition("@")
    for inst in installs or []:
        scope = inst.get("scope", "?")
        proj = inst.get("projectPath", "")
        version = inst.get("version", "?")
        print(f"{base}{SEP}{marketplace}{SEP}{scope}{SEP}{proj}{SEP}{version}")
PY
  )"

  # First pass: collect dup names.
  local DUP_NAMES=()
  local line rest
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      __DUP${SEP}*)
        rest="${line#__DUP${SEP}}"
        DUP_NAMES+=("${rest%%${SEP}*}")
        ;;
    esac
  done <<< "$PLUGIN_ROWS"

  is_dup() {
    local target="$1" d
    for d in "${DUP_NAMES[@]}"; do
      [ "$d" = "$target" ] && return 0
    done
    return 1
  }

  is_catalogued() {
    local name="$1"
    [ -f "$PLUGINS_CATALOG" ] || return 1
    python3 - "$PLUGINS_CATALOG" "$name" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
needle = sys.argv[2]
for entry in data.get("recommendations", []):
    if entry.get("name") == needle:
        sys.exit(0)
sys.exit(1)
PY
  }

  local name marketplace scope projectPath version detail
  local EXCLUDED_REASON EXCLUDED_ALT EXCLUDED_BLOB reason_line
  while IFS="$SEP" read -r name marketplace scope projectPath version; do
    [ -n "$name" ] || continue
    [ "$name" = "__DUP" ] && continue
    detail="marketplace=$marketplace scope=$scope version=$version"
    [ -n "$projectPath" ] && detail="$detail path=$projectPath"

    if [ "$scope" = "project" ] && [ -n "$projectPath" ] && [ ! -d "$projectPath" ]; then
      emit plugins "$name@$marketplace" "DROP-STALE" \
        "projectPath does not exist on disk" "$detail"
      continue
    fi

    if is_dup "$name"; then
      emit plugins "$name@$marketplace" "REBIND" \
        "duplicate install — same plugin name from multiple marketplaces or scopes" "$detail"
      continue
    fi

    # Self-reference: ai-kit's own plugin is OWNED (or REBIND when project-scoped).
    if [ -n "$SELF_PLUGIN_NAME" ] && [ "$name" = "$SELF_PLUGIN_NAME" ]; then
      if [ "$scope" = "project" ]; then
        emit plugins "$name@$marketplace" "REBIND" \
          "ai-kit itself is project-scoped; cross-project use needs --scope user" "$detail"
      else
        emit plugins "$name@$marketplace" "OWNED" \
          "ai-kit's own plugin (self-reference — not catalogued by design)" "$detail"
      fi
      continue
    fi

    if is_catalogued "$name"; then
      emit plugins "$name@$marketplace" "OWNED" \
        "in standards/external/plugins.json" "$detail"
      continue
    fi

    # Deliberately-excluded check — overlap ai-kit own skills, suggest uninstall.
    EXCLUDED_REASON=""
    EXCLUDED_ALT=""
    if [ -f "$PLUGINS_EXCLUDED" ]; then
      EXCLUDED_BLOB="$(python3 - "$PLUGINS_EXCLUDED" "$name" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
needle = sys.argv[2]
for entry in data.get("excluded", []):
    if entry.get("name") == needle:
        print(entry.get("reason", "deliberately excluded"))
        print(entry.get("alternative", ""))
        sys.exit(0)
PY
      )"
      EXCLUDED_REASON="$(printf '%s\n' "$EXCLUDED_BLOB" | sed -n '1p')"
      EXCLUDED_ALT="$(printf '%s\n' "$EXCLUDED_BLOB" | sed -n '2p')"
    fi
    if [ -n "$EXCLUDED_REASON" ]; then
      reason_line="ai-kit equivalent exists (deliberately excluded): $EXCLUDED_REASON"
      [ -n "$EXCLUDED_ALT" ] && reason_line="$reason_line — use: $EXCLUDED_ALT"
      emit plugins "$name@$marketplace" "EXCLUDED" "$reason_line" "$detail"
      continue
    fi

    emit plugins "$name@$marketplace" "ADOPT" \
      "installed but not in ai-kit catalog — promotion candidate" "$detail"
  done <<< "$PLUGIN_ROWS"
}
