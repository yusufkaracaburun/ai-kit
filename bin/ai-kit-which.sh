#!/usr/bin/env bash
# ai-kit-which.sh — pick the right ai-kit skill for what you're trying to do.
#
# Usage:
#   ai-kit-which.sh "I want to write a PRD for the new feature"
#       Score every skill's description against the intent text; print top-3.
#   ai-kit-which.sh --list
#       List all 16 skills with a one-line description.
#   ai-kit-which.sh --explain <skill>
#       Print the full SKILL.md for the named skill.
#   ai-kit-which.sh
#       Interactive — prompt for the intent on stdin, then score.
#
# Scoring is deterministic: keyword overlap between the intent and each
# skill's description, with bonus weight for matches against the skill name.
# No network, no LLM, no dependencies beyond bash + awk.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

SKILLS_DIR="$AIKIT/workflow/skills"

# Stopwords — words common to both intents and descriptions that carry no
# discriminating signal. Keep nouns/verbs/adjectives untouched.
STOPWORDS="a an and or but the this that these those is are was were be been being am i we you it
my our your their want need would like to from at on in for of with by how can do does did
help me us please thanks ok now then when where what why which who whom there here so just very
about into out over under after before some any all also as if not no yes off"

usage() {
  sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

skill_description() {
  awk '
    /^---$/ { n++; if (n>=2) exit; next }
    /^description:/ {
      sub(/^description:[[:space:]]*"?/, "")
      sub(/"[[:space:]]*$/, "")
      print
      exit
    }
  ' "$1"
}

list_skills() {
  printf '%-32s %s\n' "SKILL" "DESCRIPTION"
  printf '%-32s %s\n' "-----" "-----------"
  for dir in "$SKILLS_DIR"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    name="$(basename "$dir")"
    desc="$(skill_description "$dir/SKILL.md")"
    if [ "${#desc}" -gt 92 ]; then
      desc="${desc:0:89}..."
    fi
    printf '%-32s %s\n' "$name" "$desc"
  done
}

explain_skill() {
  local name="$1"
  local file="$SKILLS_DIR/$name/SKILL.md"
  if [ ! -f "$file" ]; then
    echo "No skill named '$name'." >&2
    echo "Try: $(basename "$0") --list" >&2
    exit 1
  fi
  cat "$file"
}

# Build a regex of stopwords for awk to ignore.
stopwords_pattern() {
  printf '%s' "$STOPWORDS" | tr ' \n' '||' | sed 's/||*/|/g; s/^|//; s/|$//'
}

# Score every skill against the intent. Prints lines: "<score>\t<name>\t<matches>\t<desc>"
score_skills() {
  local intent="$1"
  local stop_pat
  stop_pat="$(stopwords_pattern)"

  # Tokenise the intent: lowercase, alpha+digit only, split on non-word.
  # Then drop stopwords and very short (<3) tokens.
  local tokens
  tokens="$(printf '%s' "$intent" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' '\n' \
    | awk -v stop="^($stop_pat)\$" 'length($0) >= 3 && $0 !~ stop' \
    | sort -u)"

  if [ -z "$tokens" ]; then
    return 0
  fi

  for dir in "$SKILLS_DIR"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    local name desc desc_lc score matches
    name="$(basename "$dir")"
    desc="$(skill_description "$dir/SKILL.md")"
    desc_lc="$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]')"
    score=0
    matches=""

    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      # Whole-word match in description: 1 point.
      if printf '%s' "$desc_lc" | grep -qwF "$tok"; then
        score=$((score + 1))
        matches="${matches}${tok} "
      fi
      # Match against skill name: +2 (high signal — the user said the topic).
      if printf '%s' "$name" | grep -qwF "$tok"; then
        score=$((score + 2))
        matches="${matches}!${tok} "
      fi
    done <<EOF
$tokens
EOF

    if [ "$score" -gt 0 ]; then
      # Trim trailing space from matches.
      matches="${matches% }"
      printf '%d\t%s\t%s\t%s\n' "$score" "$name" "$matches" "$desc"
    fi
  done
}

recommend() {
  local intent="$1"
  local results
  results="$(score_skills "$intent")"

  if [ -z "$results" ]; then
    echo "No skill description matched any token in your intent."
    echo ""
    echo "Try:"
    echo "  $(basename "$0") --list                  # browse all 16 skills"
    echo "  $(basename "$0") <topic>                 # search by a single word"
    return 1
  fi

  echo "Intent: $intent"
  echo ""
  echo "Top matches (deterministic keyword overlap — verify by reading the SKILL.md):"
  echo ""

  local rank=0
  while IFS=$'\t' read -r score name matches desc; do
    [ -z "$name" ] && continue
    rank=$((rank + 1))
    [ "$rank" -gt 3 ] && break
    printf '%d. /%s   (score %s)\n' "$rank" "$name" "$score"
    # Wrap description at ~85 cols, indent 4.
    printf '%s\n' "$desc" | fold -s -w 85 | sed 's/^/    /'
    printf '    Matched: %s\n' "$matches"
    printf '    Skill:   %s/workflow/skills/%s/SKILL.md\n' "$AIKIT" "$name"
    echo ""
  done < <(printf '%s\n' "$results" | sort -k1,1nr -k2,2)

  if [ "$rank" -eq 0 ]; then
    echo "No matches above score 0."
    return 1
  fi
  return 0
}

# --- entry point ---

case "${1:-}" in
  -h|--help) usage ;;
  --list) list_skills; exit 0 ;;
  --explain)
    [ -n "${2:-}" ] || { echo "Missing skill name." >&2; usage; }
    explain_skill "$2"
    exit 0
    ;;
  "")
    # Interactive
    printf 'What are you trying to do? > '
    IFS= read -r INTENT
    [ -z "$INTENT" ] && { echo "(no input)" >&2; exit 2; }
    recommend "$INTENT"
    ;;
  *)
    recommend "$*"
    ;;
esac
