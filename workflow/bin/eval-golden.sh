#!/usr/bin/env bash
# eval-golden.sh — score a response file against a structured rubric.
#
# Each rubric lives in tests/eval/goldens/<skill>/<scenario>.md as YAML
# frontmatter (flat top-level keys: required_headings, required_keywords,
# required_phrases, forbidden_keywords, min_lines, max_lines).
#
# Usage:
#   eval-golden.sh --validate-all
#       Run every golden against its own rubric (CI sanity check).
#   eval-golden.sh <skill> <scenario>
#       Validate the named golden against its own rubric.
#   eval-golden.sh <skill> <scenario> <response-file>
#       Score the response file against the rubric.
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  usage / file-not-found error
#
# No network, no LLM calls — purely deterministic text checks.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

GOLDENS_DIR="$AIKIT/tests/eval/goldens"

usage() {
  sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# Extract the body of a markdown file (everything after the second `---`).
body_of() {
  awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$1"
}

# Extract a YAML list under a top-level key (one item per line, leading "- " stripped).
list_field() {
  local file="$1" key="$2"
  awk -v k="^${key}:" '
    BEGIN{flag=0}
    $0 ~ k {flag=1; next}
    /^[A-Za-z_]+:/ {flag=0}
    flag && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      gsub(/^"|"$/, "")
      gsub(/^'\''|'\''$/, "")
      print
    }
  ' "$file"
}

# Extract a scalar top-level key.
scalar_field() {
  local file="$1" key="$2"
  awk -v k="^${key}:" '
    $0 ~ k {
      sub(/^[A-Za-z_]+:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}

# Run a rubric (golden file) against a response file.
# $1 = rubric file (a golden); $2 = response file (often the same golden).
# Prints OK/FAIL lines and returns 0 if all checks pass.
score() {
  local rubric="$1" response="$2"
  local label="${3:-$(basename "$(dirname "$rubric")")/$(basename "$rubric" .md)}"
  local passes=0 fails=0

  if [ ! -f "$rubric" ]; then
    echo "  ERR: rubric not found: $rubric" >&2
    return 2
  fi
  if [ ! -f "$response" ]; then
    echo "  ERR: response not found: $response" >&2
    return 2
  fi

  local body
  body="$(body_of "$response")"

  # required_headings — exact-line match in the body
  while IFS= read -r heading; do
    [ -z "$heading" ] && continue
    if printf '%s\n' "$body" | grep -qxF "$heading"; then
      echo "  OK   [$label] heading: $heading"
      passes=$((passes + 1))
    else
      echo "  FAIL [$label] missing heading: $heading"
      fails=$((fails + 1))
    fi
  done < <(list_field "$rubric" required_headings)

  # required_keywords — case-insensitive substring match anywhere in body
  while IFS= read -r kw; do
    [ -z "$kw" ] && continue
    if printf '%s' "$body" | grep -qiF "$kw"; then
      echo "  OK   [$label] keyword: $kw"
      passes=$((passes + 1))
    else
      echo "  FAIL [$label] missing keyword: $kw"
      fails=$((fails + 1))
    fi
  done < <(list_field "$rubric" required_keywords)

  # required_phrases — case-SENSITIVE substring match
  while IFS= read -r phrase; do
    [ -z "$phrase" ] && continue
    if printf '%s' "$body" | grep -qF "$phrase"; then
      echo "  OK   [$label] phrase: $phrase"
      passes=$((passes + 1))
    else
      echo "  FAIL [$label] missing phrase: $phrase"
      fails=$((fails + 1))
    fi
  done < <(list_field "$rubric" required_phrases)

  # forbidden_keywords — must NOT appear (case-insensitive)
  while IFS= read -r kw; do
    [ -z "$kw" ] && continue
    if printf '%s' "$body" | grep -qiF "$kw"; then
      echo "  FAIL [$label] forbidden keyword present: $kw"
      fails=$((fails + 1))
    else
      echo "  OK   [$label] forbidden absent: $kw"
      passes=$((passes + 1))
    fi
  done < <(list_field "$rubric" forbidden_keywords)

  # min_lines / max_lines on body
  local body_lines min_lines max_lines
  body_lines="$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
  min_lines="$(scalar_field "$rubric" min_lines)"
  max_lines="$(scalar_field "$rubric" max_lines)"

  if [ -n "$min_lines" ]; then
    if [ "$body_lines" -ge "$min_lines" ]; then
      echo "  OK   [$label] body lines $body_lines >= min $min_lines"
      passes=$((passes + 1))
    else
      echo "  FAIL [$label] body lines $body_lines < min $min_lines"
      fails=$((fails + 1))
    fi
  fi
  if [ -n "$max_lines" ]; then
    if [ "$body_lines" -le "$max_lines" ]; then
      echo "  OK   [$label] body lines $body_lines <= max $max_lines"
      passes=$((passes + 1))
    else
      echo "  FAIL [$label] body lines $body_lines > max $max_lines"
      fails=$((fails + 1))
    fi
  fi

  printf '  ---- %s: %d passed, %d failed\n' "$label" "$passes" "$fails"

  if [ "$fails" -gt 0 ]; then
    return 1
  fi
  return 0
}

case "${1:-}" in
  ""|-h|--help) usage ;;
  --validate-all)
    if [ ! -d "$GOLDENS_DIR" ]; then
      echo "No goldens directory: $GOLDENS_DIR" >&2
      exit 2
    fi
    total_pass=0
    total_fail=0
    while IFS= read -r golden; do
      [ -z "$golden" ] && continue
      skill_name="$(basename "$(dirname "$golden")")"
      scenario_name="$(basename "$golden" .md)"
      echo "=== $skill_name / $scenario_name ==="
      if score "$golden" "$golden" "$skill_name/$scenario_name"; then
        total_pass=$((total_pass + 1))
      else
        total_fail=$((total_fail + 1))
      fi
      echo ""
    done < <(find "$GOLDENS_DIR" -name '*.md' -type f | sort)
    echo "Goldens passing rubric: $total_pass    failing: $total_fail"
    if [ "$total_fail" -gt 0 ]; then exit 1; fi
    exit 0
    ;;
  *)
    SKILL="$1"
    SCENARIO="${2:-}"
    RESPONSE="${3:-}"
    if [ -z "$SCENARIO" ]; then
      echo "Missing scenario." >&2
      usage
    fi
    GOLDEN="$GOLDENS_DIR/$SKILL/$SCENARIO.md"
    if [ ! -f "$GOLDEN" ]; then
      echo "No golden at $GOLDEN" >&2
      exit 2
    fi
    if [ -z "$RESPONSE" ]; then
      RESPONSE="$GOLDEN"
    fi
    score "$GOLDEN" "$RESPONSE" "$SKILL/$SCENARIO"
    ;;
esac
