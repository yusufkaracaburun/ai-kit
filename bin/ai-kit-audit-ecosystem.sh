#!/usr/bin/env bash
# Audit broader Claude Code primitive state on the host machine and emit a
# verdict per item against ai-kit's catalogs. Read-only: never modifies state.
# --converge prints a migration recipe but does not execute it.
#
# Surfaces:
#   plugins      — ~/.claude/plugins/installed_plugins.json entries
#   marketplaces — ~/.claude/plugins/known_marketplaces.json entries
#   skills       — ~/.claude/skills/*
#   agents       — ~/.claude/agents/*.md
#   rules        — ~/.claude/rules/*.md
#   mcp          — mcpServers block in ~/.claude/settings.json
#
# Verdicts:
#   OWNED          — ai-kit catalog already includes this; nothing to do
#   ADOPT          — present on machine, not catalogued → promotion candidate
#   REBIND         — scope mismatch (project-scoped where user-scope makes
#                    sense) or duplicate marketplace install
#   REPLACE        — ai-kit ships a functional equivalent
#   DROP-STALE     — references a path that no longer exists on disk
#   KEEP-EXTERNAL  — valid, out of ai-kit scope
set -o pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"

usage() {
  cat <<USAGE
Usage: $0 [--json] [--scope SCOPE] [--converge] [--strict] [--home DIR] [--catalog-root DIR]

Audit host Claude Code primitive state (installed plugins, user-scope skills/
agents/rules, MCP servers) against ai-kit catalogs. Emit per-item verdicts:
OWNED, ADOPT, REBIND, REPLACE, EXCLUDED, DROP-STALE, KEEP-EXTERNAL.

Options:
  --json              Machine-readable output.
  --scope SCOPE       Limit to one surface (plugins|marketplaces|skills|
                      agents|rules|mcp|all). Default: all.
  --converge          Print executable migration recipe (does NOT execute).
  --strict            Exit 1 when divergent findings are present (for CI).
                      Default is exit 0 always — this script is report-
                      only, and a non-zero exit confuses tooling that
                      treats it as failure.
  --home DIR          Override host root (default: \$HOME). Tests inject
                      fixture trees this way.
  --catalog-root DIR  Override ai-kit catalog root (default: resolved
                      AI_KIT_ROOT). Tests use this for synthetic catalogs.
  -h, --help          Show this message.

Exit codes:
  0  ran successfully (with or without divergent findings)
  1  divergent findings present AND --strict was passed
  2  usage error
USAGE
}

MODE_JSON=0
MODE_CONVERGE=0
MODE_STRICT=0
SCOPE_FILTER="all"
HOME_DIR="$HOME"
CATALOG_ROOT="$AIKIT"
CATALOG_PRIMITIVES="$PRIMITIVES"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) MODE_JSON=1; shift ;;
    --converge) MODE_CONVERGE=1; shift ;;
    --strict) MODE_STRICT=1; shift ;;
    --scope)
      [ -n "${2:-}" ] || { echo "--scope requires value" >&2; exit 2; }
      SCOPE_FILTER="$2"; shift 2 ;;
    --home)
      [ -n "${2:-}" ] || { echo "--home requires value" >&2; exit 2; }
      HOME_DIR="$2"; shift 2 ;;
    --catalog-root)
      [ -n "${2:-}" ] || { echo "--catalog-root requires value" >&2; exit 2; }
      CATALOG_ROOT="$2"
      CATALOG_PRIMITIVES="$(resolve_primitives_root "$CATALOG_ROOT")"
      shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# Self-reference: the audit must never flag ai-kit's own plugin as an ADOPT
# candidate (you can't ship yourself in your own catalog). Detect by reading
# the plugin manifest's `name` field from CATALOG_ROOT.
SELF_PLUGIN_NAME=""
for self_manifest in "$CATALOG_ROOT/workflow/.claude-plugin/plugin.json" "$CATALOG_ROOT/.claude-plugin/plugin.json"; do
  if [ -f "$self_manifest" ]; then
    SELF_PLUGIN_NAME="$(python3 -c "
import json, sys
try:
    print(json.load(open('$self_manifest')).get('name', ''))
except Exception:
    pass
" 2>/dev/null)"
    [ -n "$SELF_PLUGIN_NAME" ] && break
  fi
done

case "$SCOPE_FILTER" in
  all|plugins|marketplaces|skills|agents|rules|mcp) ;;
  *) echo "Invalid --scope: $SCOPE_FILTER" >&2; exit 2 ;;
esac

INSTALLED_PLUGINS="$HOME_DIR/.claude/plugins/installed_plugins.json"
KNOWN_MARKETPLACES="$HOME_DIR/.claude/plugins/known_marketplaces.json"
USER_SKILLS_DIR="$HOME_DIR/.claude/skills"
USER_AGENTS_DIR="$HOME_DIR/.claude/agents"
USER_RULES_DIR="$HOME_DIR/.claude/rules"
USER_SETTINGS="$HOME_DIR/.claude/settings.json"

PLUGINS_CATALOG="$CATALOG_ROOT/standards/external/plugins.json"
PLUGINS_EXCLUDED="$CATALOG_ROOT/standards/external/plugins-excluded.json"
MCP_CATALOG="$CATALOG_ROOT/standards/external/mcp-servers.json"
PLUGIN_SKILLS_DIR="$CATALOG_PRIMITIVES/skills"
PLUGIN_AGENTS_DIR="$CATALOG_PRIMITIVES/agents"
PLUGIN_RULES_DIR="$CATALOG_ROOT/standards/rules"

# Output records: "surface\tname\tverdict\treason\tdetail"
RECORDS=()

SEP=$'\x1f'

emit() {
  local surface="$1" name="$2" verdict="$3" reason="$4" detail="${5:-}"
  RECORDS+=("${surface}${SEP}${name}${SEP}${verdict}${SEP}${reason}${SEP}${detail}")
}

want_scope() {
  [ "$SCOPE_FILTER" = "all" ] || [ "$SCOPE_FILTER" = "$1" ]
}

# ---------------------------------------------------------------------------
# Plugin entries
# ---------------------------------------------------------------------------
if want_scope plugins && [ -f "$INSTALLED_PLUGINS" ]; then
  # Python helper emits one TSV row per (plugin, install) tuple, plus a
  # synthetic row "__DUP\t<name>\t<count>" when one plugin name has multiple
  # entries (typically dual-marketplace installs).
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

  # First pass: collect dup names so we can flag them.
  DUP_NAMES=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      __DUP${SEP}*)
        # Extract name field (between first and second SEP).
        rest="${line#__DUP${SEP}}"
        DUP_NAMES+=("${rest%%${SEP}*}")
        ;;
    esac
  done <<< "$PLUGIN_ROWS"

  is_dup() {
    local target="$1"
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

    # Self-reference: ai-kit can never recommend ai-kit-itself into its own
    # catalog. Treat as OWNED (the install is correct) unless it's project-
    # scoped (then suggest user-scope rebind).
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

    # Deliberately-excluded check — these plugins overlap ai-kit's own skills
    # and should not be ADOPT'd. Surface as EXCLUDED (distinct from REPLACE,
    # which is reserved for user-scope skill/agent shadowing) so the audit can
    # surface an uninstall suggestion with the recorded reason.
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
fi

# ---------------------------------------------------------------------------
# Marketplaces
# ---------------------------------------------------------------------------
if want_scope marketplaces && [ -f "$KNOWN_MARKETPLACES" ] && [ -f "$INSTALLED_PLUGINS" ]; then
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
  while IFS="$SEP" read -r mkt count repo; do
    [ -n "$mkt" ] || continue
    detail="installs=$count repo=$repo"
    if [ "$count" -eq 0 ]; then
      emit marketplaces "$mkt" "DROP" "marketplace registered but no plugins installed from it" "$detail"
    else
      emit marketplaces "$mkt" "KEEP-EXTERNAL" "active marketplace" "$detail"
    fi
  done <<< "$MKT_ROWS"
fi

# ---------------------------------------------------------------------------
# User-scope skills — REPLACE if shadowing plugin skill, else KEEP-EXTERNAL.
# ---------------------------------------------------------------------------
if want_scope skills && [ -d "$USER_SKILLS_DIR" ]; then
  for skill_path in "$USER_SKILLS_DIR"/*/; do
    [ -d "$skill_path" ] || continue
    name="$(basename "$skill_path")"
    if [ -d "$PLUGIN_SKILLS_DIR/$name" ]; then
      emit skills "$name" "REPLACE" \
        "ai-kit ships skills/$name — personal copy shadows the plugin version" \
        "user_path=$skill_path"
    else
      emit skills "$name" "KEEP-EXTERNAL" \
        "user-scope skill not owned by ai-kit" \
        "user_path=$skill_path"
    fi
  done
fi

# ---------------------------------------------------------------------------
# User-scope agents — REPLACE if shadowing plugin agent, else KEEP-EXTERNAL.
# ---------------------------------------------------------------------------
if want_scope agents && [ -d "$USER_AGENTS_DIR" ]; then
  for agent_file in "$USER_AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    name="$(basename "$agent_file" .md)"
    if [ -d "$PLUGIN_AGENTS_DIR/$name" ]; then
      emit agents "$name" "REPLACE" \
        "ai-kit ships agents/$name — personal copy shadows the plugin version" \
        "user_path=$agent_file"
    else
      emit agents "$name" "KEEP-EXTERNAL" \
        "user-scope agent not owned by ai-kit" \
        "user_path=$agent_file"
    fi
  done
fi

# ---------------------------------------------------------------------------
# User-scope rules — OWNED if matches plugin rule stem or universal MCP rule.
# ---------------------------------------------------------------------------
if want_scope rules && [ -d "$USER_RULES_DIR" ]; then
  PLUGIN_RULE_STEMS=()
  if [ -d "$PLUGIN_RULES_DIR" ]; then
    for rule_file in "$PLUGIN_RULES_DIR"/*.md "$PLUGIN_RULES_DIR"/feedback/*.md; do
      [ -f "$rule_file" ] || continue
      stem="$(basename "$rule_file")"
      stem="${stem%.mini.md}"
      stem="${stem%.nano.md}"
      stem="${stem%.md}"
      PLUGIN_RULE_STEMS+=("$stem")
    done
  fi

  MCP_UNIVERSAL=()
  if [ -f "$MCP_CATALOG" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && MCP_UNIVERSAL+=("$line")
    done < <(python3 - "$MCP_CATALOG" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for e in data.get("recommendations", []):
    if e.get("universal"):
        print(e.get("name", ""))
PY
    )
  fi

  for rule_file in "$USER_RULES_DIR"/*.md; do
    [ -f "$rule_file" ] || continue
    name="$(basename "$rule_file" .md)"
    found=0
    for stem in "${PLUGIN_RULE_STEMS[@]}"; do
      [ "$stem" = "$name" ] && { found=1; break; }
    done
    if [ "$found" -eq 0 ]; then
      for mcp in "${MCP_UNIVERSAL[@]}"; do
        [ "$mcp" = "$name" ] && { found=1; break; }
      done
    fi
    if [ "$found" -eq 1 ]; then
      emit rules "$name" "OWNED" \
        "rule covered by ai-kit catalog (canonical rule or universal MCP)" \
        "user_path=$rule_file"
    else
      emit rules "$name" "KEEP-EXTERNAL" \
        "user-scope rule not in ai-kit catalog" \
        "user_path=$rule_file"
    fi
  done
fi

# ---------------------------------------------------------------------------
# MCP servers in user settings.json
# ---------------------------------------------------------------------------
if want_scope mcp && [ -f "$USER_SETTINGS" ]; then
  MCP_ROWS="$(python3 - "$USER_SETTINGS" "$MCP_CATALOG" <<'PY'
import json, sys, os
SEP = "\x1f"
settings = json.load(open(sys.argv[1]))
mcp = settings.get("mcpServers") or {}
catalog_path = sys.argv[2]
catalog = set()
if os.path.exists(catalog_path):
    for e in json.load(open(catalog_path)).get("recommendations", []):
        if e.get("name"):
            catalog.add(e["name"])
for name, meta in mcp.items():
    transport = meta.get("type") or ("stdio" if "command" in meta else "?")
    catalogued = "yes" if name in catalog else "no"
    print(f"{name}{SEP}{transport}{SEP}{catalogued}")
PY
  )"
  while IFS="$SEP" read -r name transport catalogued; do
    [ -n "$name" ] || continue
    detail="transport=$transport"
    if [ "$catalogued" = "yes" ]; then
      emit mcp "$name" "OWNED" "in standards/external/mcp-servers.json" "$detail"
    else
      emit mcp "$name" "ADOPT" "MCP server installed user-scope but not catalogued" "$detail"
    fi
  done <<< "$MCP_ROWS"
fi

# ---------------------------------------------------------------------------
# Aggregate exit code
# ---------------------------------------------------------------------------
parse_rec() {
  # Sets globals rec_surface rec_name rec_verdict rec_reason rec_detail from $1.
  local raw="$1"
  IFS="$SEP" read -r rec_surface rec_name rec_verdict rec_reason rec_detail <<< "$raw"
}

DIVERGENT=0
for rec in "${RECORDS[@]:-}"; do
  [ -z "$rec" ] && continue
  parse_rec "$rec"
  case "$rec_verdict" in
    OWNED|KEEP-EXTERNAL) ;;
    *) DIVERGENT=$((DIVERGENT + 1)) ;;
  esac
done

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [ "$MODE_JSON" -eq 1 ]; then
  JSON_SCRIPT='
import json, sys, os
out = {
    "home": os.environ["HOME_DIR"],
    "catalog_root": os.environ["CATALOG_ROOT"],
    "scope": os.environ["SCOPE_FILTER"],
    "findings": [],
}
for raw in sys.stdin:
    raw = raw.rstrip("\n")
    if not raw:
        continue
    parts = raw.split("\x1f")
    while len(parts) < 5:
        parts.append("")
    out["findings"].append({
        "surface": parts[0],
        "name": parts[1],
        "verdict": parts[2],
        "reason": parts[3],
        "detail": parts[4],
    })
out["total"] = len(out["findings"])
out["divergent"] = sum(
    1 for f in out["findings"] if f["verdict"] not in ("OWNED", "KEEP-EXTERNAL")
)
print(json.dumps(out, indent=2))
'
  {
    for rec in "${RECORDS[@]:-}"; do
      [ -n "$rec" ] && printf '%s\n' "$rec"
    done
  } | HOME_DIR="$HOME_DIR" CATALOG_ROOT="$CATALOG_ROOT" SCOPE_FILTER="$SCOPE_FILTER" \
      python3 -c "$JSON_SCRIPT"
  if [ "$MODE_STRICT" -eq 1 ] && [ "$DIVERGENT" -gt 0 ]; then exit 1; else exit 0; fi
fi

# Human-readable
echo "ai-kit ecosystem audit"
echo "  home              $HOME_DIR"
echo "  ai-kit catalog    $CATALOG_ROOT"
echo "  scope             $SCOPE_FILTER"
echo ""

print_surface() {
  local target_surface="$1" header="$2"
  echo "$header"
  local printed=0
  for rec in "${RECORDS[@]:-}"; do
    [ -z "$rec" ] && continue
    parse_rec "$rec"
    [ "$rec_surface" = "$target_surface" ] || continue
    printf "  %-14s %-30s %s\n" "$rec_verdict" "$rec_name" "$rec_reason"
    [ -n "$rec_detail" ] && printf "                 %-30s %s\n" "" "$rec_detail"
    printed=$((printed + 1))
  done
  [ "$printed" -eq 0 ] && echo "  (no entries inspected)"
  echo ""
}

want_scope plugins      && print_surface plugins      "Surface — Plugins"
want_scope marketplaces && print_surface marketplaces "Surface — Marketplaces"
want_scope skills       && print_surface skills       "Surface — User skills"
want_scope agents       && print_surface agents       "Surface — User agents"
want_scope rules        && print_surface rules        "Surface — User rules"
want_scope mcp          && print_surface mcp          "Surface — User MCP servers"

if [ "$MODE_CONVERGE" -eq 1 ] && [ "$DIVERGENT" -gt 0 ]; then
  echo "Convergence recipe (review before running — script does NOT execute)"
  for rec in "${RECORDS[@]:-}"; do
    [ -z "$rec" ] && continue
    parse_rec "$rec"
    case "$rec_verdict" in
      DROP-STALE)
        case "$rec_surface" in
          plugins)
            echo "  /plugin uninstall $rec_name   # stale projectPath"
            ;;
        esac
        ;;
      REBIND)
        case "$rec_surface" in
          plugins)
            echo "  /plugin uninstall $rec_name && /plugin install $rec_name --scope user   # rebind"
            ;;
        esac
        ;;
      REPLACE)
        case "$rec_surface" in
          skills)
            echo "  rm -rf \"$USER_SKILLS_DIR/$rec_name\"   # ai-kit ships skills/$rec_name"
            ;;
          agents)
            echo "  rm \"$USER_AGENTS_DIR/$rec_name.md\"   # ai-kit ships agents/$rec_name"
            ;;
        esac
        ;;
      EXCLUDED)
        case "$rec_surface" in
          plugins)
            # rec_reason already embeds the alternative — strip the "ai-kit equivalent exists..." prefix.
            alt_hint="$(printf '%s' "$rec_reason" | sed -n 's/.*— use: //p')"
            if [ -n "$alt_hint" ]; then
              echo "  /plugin uninstall $rec_name   # ai-kit equivalent: $alt_hint"
            else
              echo "  /plugin uninstall $rec_name   # ai-kit ships equivalent (see plugins-excluded.json)"
            fi
            ;;
        esac
        ;;
      DROP)
        case "$rec_surface" in
          marketplaces)
            echo "  /plugin marketplace remove $rec_name   # no installs"
            ;;
        esac
        ;;
      ADOPT)
        echo "  # ADOPT candidate: $rec_surface/$rec_name — file /ai:followup to add to catalog"
        ;;
    esac
  done
  echo ""
fi

if [ "$DIVERGENT" -gt 0 ]; then
  echo "Found $DIVERGENT divergent item(s). Run with --converge to see migration recipe."
  if [ "$MODE_STRICT" -eq 1 ]; then exit 1; fi
  exit 0
else
  echo "Converged — host primitives match ai-kit catalog (or are explicitly external)."
  exit 0
fi
