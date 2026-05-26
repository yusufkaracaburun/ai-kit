# shellcheck shell=bash
# Marketplaces surface walk for ai-kit-audit-ecosystem.sh.

walk_marketplaces() {
  want_scope marketplaces || return 0
  [ -f "$KNOWN_MARKETPLACES" ] || return 0
  [ -f "$INSTALLED_PLUGINS" ] || return 0

  local MKT_ROWS
  MKT_ROWS="$(python3 - "$KNOWN_MARKETPLACES" "$INSTALLED_PLUGINS" <<'PY'
import json, sys, collections
SEP = "\x1f"
mkts = json.load(open(sys.argv[1]))
plugins = json.load(open(sys.argv[2])).get("plugins", {})
used = collections.Counter()
for key in plugins:
    _, _, m = key.partition("@")
    used[m] += 1
for name, meta in mkts.items():
    repo = (meta.get("source") or {}).get("repo") or (meta.get("source") or {}).get("url") or ""
    print(f"{name}{SEP}{used.get(name, 0)}{SEP}{repo}")
PY
  )"

  local mkt count repo detail
  while IFS="$SEP" read -r mkt count repo; do
    [ -n "$mkt" ] || continue
    detail="installs=$count repo=$repo"
    if [ "$count" -eq 0 ]; then
      emit marketplaces "$mkt" "DROP" "marketplace registered but no plugins installed from it" "$detail"
    else
      emit marketplaces "$mkt" "KEEP-EXTERNAL" "active marketplace" "$detail"
    fi
  done <<< "$MKT_ROWS"
}
