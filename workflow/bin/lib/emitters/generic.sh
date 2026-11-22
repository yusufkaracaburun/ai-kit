# shellcheck shell=bash
# Generic / AGENTS.md emitter — maintains docs/agents/active-rules.md as a
# single canonical list. Idempotent: re-emitting the same rule updates its
# row instead of appending duplicates.

emit_generic() {
  local target="$1" rule_path="$2" rule_name="$3" mode="$4" aikit_version="$5"
  local index="$target/docs/agents/active-rules.md"
  local description
  description="$(_emitter_extract_meta "$rule_path" description)"
  [ -z "$description" ] && description="(no description)"

  mkdir -p "$(dirname "$index")"

  local tmp
  tmp="$(mktemp)"
  {
    echo "# Active rules"
    echo ""
    echo "Canonical rules enabled for this project. Source of truth: the ai-kit \`standards/rules/*.mini.md\` files. Re-emit existing rules with \`/ai:upgrade\`; add rules with \`/ai:recommend-rules\`."
    echo ""
    echo "<!-- ai-kit:active-rules:start -->"
    echo ""
    echo "| Rule | Mode | Description |"
    echo "| ---- | ---- | ----------- |"

    # Keep existing row order: replace this rule's row in place, else append it.
    local row="| ${rule_name} | ${mode} | ${description} |"
    if [ -f "$index" ]; then
      ROW="$row" awk -v skip="$rule_name" '
        /<!-- ai-kit:active-rules:start -->/ { in_block=1; next }
        /<!-- ai-kit:active-rules:end -->/ { in_block=0; next }
        in_block && /^\| / && $0 !~ /^\| Rule \|/ && $0 !~ /^\| -/ {
          line=$0
          # Extract rule name (column 1)
          n=split(line, parts, /[[:space:]]*\|[[:space:]]*/)
          name=parts[2]
          if (name == skip) { print ENVIRON["ROW"]; found=1 } else print line
        }
        END { if (!found) print ENVIRON["ROW"] }
      ' "$index"
    else
      echo "$row"
    fi
    echo ""
    echo "<!-- ai-kit:active-rules:end -->"
  } > "$tmp"

  command mv -f "$tmp" "$index"
  echo "emit:generic  ${index#$target/} (+ ${rule_name})"
}
