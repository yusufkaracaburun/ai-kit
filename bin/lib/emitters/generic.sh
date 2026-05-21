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
    echo "Canonical rules enabled for this project. Source of truth: \`~/.local/share/ai-kit/standards/rules/*.mini.md\`. Re-emit with \`bin/emit-rules.sh\`."
    echo ""
    echo "<!-- ai-kit:active-rules:start -->"
    echo ""
    echo "| Rule | Mode | Description |"
    echo "| ---- | ---- | ----------- |"

    # Preserve existing rows (other rules), then write/overwrite this rule's row.
    if [ -f "$index" ]; then
      awk -v skip="$rule_name" '
        /<!-- ai-kit:active-rules:start -->/ { in_block=1; next }
        /<!-- ai-kit:active-rules:end -->/ { in_block=0; next }
        in_block && /^\| / && $0 !~ /^\| Rule \|/ && $0 !~ /^\| -/ {
          line=$0
          # Extract rule name (column 1)
          n=split(line, parts, /[[:space:]]*\|[[:space:]]*/)
          name=parts[2]
          if (name != skip) print line
        }
      ' "$index"
    fi

    echo "| ${rule_name} | ${mode} | ${description} |"
    echo ""
    echo "<!-- ai-kit:active-rules:end -->"
  } > "$tmp"

  mv "$tmp" "$index"
  echo "emit:generic  ${index#$target/} (+ ${rule_name})"
}
