# shellcheck shell=bash
# Generic / AGENTS.md emitter — maintains docs/agents/active-rules.md as a
# single canonical list. Idempotent: re-emitting the same rule updates its
# row instead of appending duplicates. Only the marked block is rewritten.

emit_generic() {
  local target="$1" rule_path="$2" rule_name="$3" mode="$4" aikit_version="$5"
  local index="$target/docs/agents/active-rules.md"
  local description
  description="$(_emitter_extract_meta "$rule_path" description)"
  [ -z "$description" ] && description="(no description)"

  mkdir -p "$(dirname "$index")"

  local row="| ${rule_name} | ${mode} | ${description} |"
  if [ ! -f "$index" ]; then
    {
      echo "# Active rules"
      echo ""
      echo "Canonical rules enabled for this project. Source of truth: the ai-kit \`standards/rules/*.mini.md\` files. Re-emit existing rules with \`/ai:upgrade\`; add rules with \`/ai:recommend-rules\`."
      echo ""
      echo "<!-- ai-kit:active-rules:start -->"
      echo "<!-- ai-kit:active-rules:end -->"
    } > "$index"
  fi

  # Text outside the markers belongs to the project. No markers: append the
  # block. Start without end: close the block and keep its non-table lines.
  local tmp
  tmp="$(mktemp)"
  ROW="$row" awk -v skip="$rule_name" '
    function block() {
      print "<!-- ai-kit:active-rules:start -->"
      print ""
      print "| Rule | Mode | Description |"
      print "| ---- | ---- | ----------- |"
      for (i = 1; i <= n; i++) print rows[i]
      if (!found) print ENVIRON["ROW"]
      print ""
      print "<!-- ai-kit:active-rules:end -->"
    }
    /<!-- ai-kit:active-rules:start -->/ { in_block=1; seen=1; next }
    /<!-- ai-kit:active-rules:end -->/ { in_block=0; k=0; block(); next }
    in_block && /^\| / && $0 !~ /^\| Rule \|/ && $0 !~ /^\| -/ {
      split($0, parts, /[[:space:]]*\|[[:space:]]*/)
      if (parts[2] == skip) { rows[++n]=ENVIRON["ROW"]; found=1 } else rows[++n]=$0
      next
    }
    in_block { if ($0 !~ /^\| / && $0 != "") kept[++k]=$0; next }
    { print }
    END {
      if (in_block) { block(); for (i = 1; i <= k; i++) print kept[i] }
      else if (!seen) { if (NR) print ""; block() }
    }
  ' "$index" > "$tmp"

  command mv -f "$tmp" "$index"
  echo "emit:generic  ${index#$target/} (+ ${rule_name})"
}
