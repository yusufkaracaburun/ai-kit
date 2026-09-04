# shellcheck shell=bash
# Output renderers + exit-code computation for ai-kit-audit-ecosystem.sh.
#
# Reads rec_* vars set as a side-effect of `parse_rec` (defined in
# common.sh). Shellcheck can't follow that cross-file flow — explicitly
# initialise the names here so SC2154 doesn't fire.
rec_surface=""
rec_name=""
rec_verdict=""
rec_reason=""
rec_detail=""

count_divergent() {
  local rec count=0
  for rec in "${RECORDS[@]:-}"; do
    [ -z "$rec" ] && continue
    parse_rec "$rec"
    case "$rec_verdict" in
      OWNED|KEEP-EXTERNAL) ;;
      *) count=$((count + 1)) ;;
    esac
  done
  echo "$count"
}

render_json() {
  local JSON_SCRIPT='
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
  local rec
  {
    for rec in "${RECORDS[@]:-}"; do
      [ -n "$rec" ] && printf '%s\n' "$rec"
    done
  } | HOME_DIR="$HOME_DIR" CATALOG_ROOT="$CATALOG_ROOT" SCOPE_FILTER="$SCOPE_FILTER" \
      python3 -c "$JSON_SCRIPT"
}

print_surface() {
  local target_surface="$1" header="$2"
  echo "$header"
  local printed=0 rec
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

render_text() {
  echo "ai-kit ecosystem audit"
  echo "  home              $HOME_DIR"
  echo "  ai-kit catalog    $CATALOG_ROOT"
  echo "  scope             $SCOPE_FILTER"
  echo ""

  want_scope plugins      && print_surface plugins      "Surface — Plugins"
  want_scope marketplaces && print_surface marketplaces "Surface — Marketplaces"
  want_scope skills       && print_surface skills       "Surface — User skills"
  want_scope agents       && print_surface agents       "Surface — User agents"
  want_scope rules        && print_surface rules        "Surface — User rules"
  want_scope mcp          && print_surface mcp          "Surface — User MCP servers"
}

render_converge() {
  local rec alt_hint
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
            case "$rec_reason" in
              "ai-kit itself is project-scoped"*)
                echo "  /plugin uninstall $rec_name && /plugin install $rec_name --scope user   # rebind"
                ;;
              "marketplace collision"*)
                # Ambiguous: two unrelated plugins share a name. Not
                # auto-fixable — surface for manual review only.
                echo "  # REVIEW: $rec_name — $rec_reason"
                ;;
              *)
                # Real duplicate (scope collision) — name the losing
                # record instead of relocating a working install.
                echo "  /plugin uninstall $rec_name   # $rec_reason"
                ;;
            esac
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
}
