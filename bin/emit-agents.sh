#!/usr/bin/env bash
# emit-agents.sh — keep the generated region of workflow/agents/*/AGENT.md in
# sync with its source skill body. SKILL.md is canonical for shared reference
# sections (the review checklist, the output-format spec); the agent prompt
# only hand-writes its agent-runtime framing (Contract, Inputs, What not to do).
#
# An AGENT.md opts in with a directive immediately followed by a marked region:
#
#   <!-- emit-agents:source skill=<skill-name> sections=<Heading,Heading> -->
#   <!-- emit-agents:begin -->
#   ...generated...
#   <!-- emit-agents:end -->
#
# The emitter replaces everything between the begin/end markers with the named
# `## ` sections pulled verbatim from workflow/skills/<skill-name>/SKILL.md.
# Idempotent — re-running with no source change is a no-op.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
AGENTS_DIR="$AIKIT/workflow/agents"
SKILLS_DIR="$AIKIT/workflow/skills"

usage() {
  cat <<EOF
Usage: $0 [--check] [--dry-run] [agent-name]

Sync the generated region of workflow/agents/*/AGENT.md from the source skill.

Options:
  --check     Verify every managed AGENT.md is in sync. Exit 1 on drift. No writes.
  --dry-run   Print the diff that would be applied. No writes.
  agent-name  Limit to a single agent directory (default: all).
  -h, --help  Show this help.
EOF
  exit "${1:-1}"
}

MODE="write"
ONLY_AGENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --dry-run) MODE="dry-run" ;;
    -h|--help) usage 0 ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) ONLY_AGENT="$1" ;;
  esac
  shift
done

# Extract a `## <heading>` section from a Markdown file: the heading line
# through the line before the next top-level `## ` heading (or EOF), with
# trailing blank lines trimmed. `## ` lines inside fenced code blocks are not
# treated as headings — the output-format spec is itself a ```markdown fence
# full of `## ` lines.
extract_section() {
  local file="$1" heading="$2"
  awk -v h="## $heading" '
    $0 == h && !cap { cap = 1; buf[n++] = $0; next }
    !cap { next }
    /^```/ { infence = !infence; buf[n++] = $0; next }
    !infence && /^## / { exit }
    { buf[n++] = $0 }
    END {
      last = n - 1
      while (last >= 0 && buf[last] ~ /^[[:space:]]*$/) last--
      for (i = 0; i <= last; i++) print buf[i]
    }
  ' "$file"
}

# Concatenate the requested sections, one blank line between each.
build_generated() {
  local skill_file="$1"; shift
  local first=1 sec body
  for sec in "$@"; do
    [ "$first" -eq 1 ] || printf '\n'
    first=0
    body="$(extract_section "$skill_file" "$sec")"
    if [ -z "$body" ]; then
      echo "emit-agents: section '## $sec' not found in ${skill_file#"$AIKIT"/}" >&2
      exit 3
    fi
    printf '%s\n' "$body"
  done
}

DRIFT=0

process_agent() {
  local agent_md="$1"
  local rel="${agent_md#"$AIKIT"/}"

  local directive
  directive="$(grep -m1 'emit-agents:source' "$agent_md" || true)"
  [ -n "$directive" ] || return 0   # no directive — not a managed agent

  if ! grep -q 'emit-agents:begin' "$agent_md" || ! grep -q 'emit-agents:end' "$agent_md"; then
    echo "emit-agents: $rel has a source directive but no begin/end markers" >&2
    exit 3
  fi

  local skill sections_csv
  skill="$(printf '%s\n' "$directive" | sed -n 's/.*skill=\([^ ]*\).*/\1/p')"
  sections_csv="$(printf '%s\n' "$directive" | sed -n 's/.*sections=\(.*\) -->.*/\1/p')"
  if [ -z "$skill" ] || [ -z "$sections_csv" ]; then
    echo "emit-agents: $rel has a malformed directive (need skill= and sections=)" >&2
    exit 3
  fi

  local skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    echo "emit-agents: $rel names source skill '$skill' but $skill_file is missing" >&2
    exit 3
  fi

  local -a sections=()
  local IFS=','
  for s in $sections_csv; do sections+=("$s"); done
  unset IFS

  local genfile new_file
  genfile="$(mktemp)"
  new_file="$(mktemp)"
  build_generated "$skill_file" "${sections[@]}" > "$genfile"

  awk -v genfile="$genfile" '
    /<!-- emit-agents:begin/ {
      print; print ""
      while ((getline l < genfile) > 0) print l
      close(genfile)
      print ""
      inblock = 1
      next
    }
    /<!-- emit-agents:end/ { inblock = 0; print; next }
    !inblock { print }
  ' "$agent_md" > "$new_file"

  if cmp -s "$agent_md" "$new_file"; then
    echo "emit-agents: $rel — in sync"
    rm -f "$genfile" "$new_file"
    return 0
  fi

  case "$MODE" in
    check)
      echo "emit-agents: DRIFT — $rel is stale" >&2
      diff "$agent_md" "$new_file" >&2 || true
      DRIFT=1
      ;;
    dry-run)
      echo "emit-agents: would update $rel"
      diff "$agent_md" "$new_file" || true
      ;;
    write)
      cp "$new_file" "$agent_md"
      echo "emit-agents: updated $rel"
      ;;
  esac
  rm -f "$genfile" "$new_file"
}

found=0
for dir in "$AGENTS_DIR"/*/; do
  agent_md="${dir%/}/AGENT.md"
  [ -f "$agent_md" ] || continue
  name="$(basename "$dir")"
  if [ -n "$ONLY_AGENT" ] && [ "$ONLY_AGENT" != "$name" ]; then
    continue
  fi
  found=1
  process_agent "$agent_md"
done

if [ -n "$ONLY_AGENT" ] && [ "$found" -eq 0 ]; then
  echo "emit-agents: no agent directory named '$ONLY_AGENT' under $AGENTS_DIR" >&2
  exit 2
fi

if [ "$DRIFT" -ne 0 ]; then
  echo "emit-agents: drift detected — run bin/emit-agents.sh to regenerate" >&2
  exit 1
fi
