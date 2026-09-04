# shellcheck shell=bash
# Plugins surface walk for ai-kit-audit-ecosystem.sh.
# Expects common.sh + dispatcher globals already in scope.

walk_plugins() {
  want_scope plugins || return 0
  [ -f "$INSTALLED_PLUGINS" ] || return 0

  # Emit one row per (plugin, install) tuple: name, marketplace, scope,
  # projectPath, version, dup_reason. dup_reason is empty unless this
  # install is part of a GENUINE duplicate:
  #   - the plugin name resolves to more than one marketplace, or
  #   - the same project path is enabled at both scope=local and
  #     scope=project (the local entry is redundant — project already
  #     covers that repo), or
  #   - a scope=user install already covers every project, making a
  #     scope=project/local install of the same plugin redundant.
  # Enabling the same (name, marketplace) in several distinct projects is
  # NOT a duplicate — that's normal per-project usage — so it never sets
  # dup_reason.
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

by_name = collections.defaultdict(list)
for key, installs in plugins.items():
    base, _, marketplace = key.partition("@")
    for inst in installs or []:
        by_name[base].append({
            "marketplace": marketplace,
            "scope": inst.get("scope", "?"),
            "projectPath": inst.get("projectPath", ""),
            "version": inst.get("version", "?"),
        })

for base, records in by_name.items():
    marketplaces = sorted(set(r["marketplace"] for r in records))
    if len(marketplaces) > 1:
        for r in records:
            r["dup_reason"] = (
                "marketplace collision — '" + base + "' installed from "
                "multiple marketplaces: " + ", ".join(marketplaces)
            )
        continue

    by_path = collections.defaultdict(list)
    user_records = []
    for r in records:
        if r["scope"] == "user":
            user_records.append(r)
        else:
            by_path[r["projectPath"]].append(r)

    for proj, recs in by_path.items():
        scopes = set(r["scope"] for r in recs)
        if "local" in scopes and "project" in scopes:
            for r in recs:
                if r["scope"] == "local":
                    r["dup_reason"] = (
                        "scope collision — enabled at both scope=local and "
                        "scope=project for the same project path (" + proj +
                        "); the scope=local entry is redundant, "
                        "scope=project already covers it"
                    )

    if user_records:
        for r in records:
            if r["scope"] != "user" and "dup_reason" not in r:
                r["dup_reason"] = (
                    "scope collision — already enabled at scope=user "
                    "(covers all projects); this scope=" + r["scope"] +
                    " entry for " + (r["projectPath"] or "(no path)") +
                    " is redundant"
                )

for base, records in by_name.items():
    for r in records:
        reason = r.get("dup_reason", "")
        print(f"{base}{SEP}{r['marketplace']}{SEP}{r['scope']}{SEP}{r['projectPath']}{SEP}{r['version']}{SEP}{reason}")
PY
  )"

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

  local name marketplace scope projectPath version dup_reason detail
  local EXCLUDED_REASON EXCLUDED_ALT EXCLUDED_BLOB reason_line
  while IFS="$SEP" read -r name marketplace scope projectPath version dup_reason; do
    [ -n "$name" ] || continue
    detail="marketplace=$marketplace scope=$scope version=$version"
    [ -n "$projectPath" ] && detail="$detail path=$projectPath"

    if [ "$scope" = "project" ] && [ -n "$projectPath" ] && [ ! -d "$projectPath" ]; then
      emit plugins "$name@$marketplace" "DROP-STALE" \
        "projectPath does not exist on disk" "$detail"
      continue
    fi

    if [ -n "$dup_reason" ]; then
      emit plugins "$name@$marketplace" "REBIND" "$dup_reason" "$detail"
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
