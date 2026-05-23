#!/usr/bin/env bash
# Structural checks across all workflow/skills/*/SKILL.md and tests/eval/prompts/.
# Pure, deterministic, no network. Run from ai-kit clone root or via run-all.sh.
set -euo pipefail

AIKIT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_DIR="$AIKIT/workflow/skills"
PROMPTS_DIR="$AIKIT/tests/eval/prompts"

PASS=0
FAIL=0
FAIL_DETAILS=()

ok()  { echo "  OK: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); FAIL_DETAILS+=("$1"); }

frontmatter() {
  awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print} n>=2{exit}' "$1"
}

body() {
  awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$1"
}

read_field() {
  local file="$1" field="$2"
  frontmatter "$file" | awk -v f="$field" '
    $0 ~ "^" f ":" {
      sub("^" f ":[[:space:]]*", "")
      print
      exit
    }'
}

echo "=== SKILL.md structural checks ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    bad "[$name] missing SKILL.md"
    continue
  fi

  # 1 + 2: frontmatter has name + description, name matches dir
  fm_name="$(read_field "$skill_file" name)"
  fm_desc="$(read_field "$skill_file" description)"

  if [ -z "$fm_name" ]; then
    bad "[$name] frontmatter missing 'name:'"
  elif [ "$fm_name" != "$name" ]; then
    bad "[$name] frontmatter name '$fm_name' != dir name"
  else
    ok "[$name] frontmatter name matches dir"
  fi

  # Cross-tool naming: Claude Code + Cursor both expect lowercase-hyphen names
  # (no spaces, no uppercase, no underscores). Invalid characters break skill
  # discovery in one tool or the other.
  if printf '%s' "$fm_name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    ok "[$name] name uses lowercase + hyphens only"
  elif [ -n "$fm_name" ]; then
    bad "[$name] name '$fm_name' must be lowercase letters/digits/hyphens (cross-tool requirement)"
  fi

  # Cross-tool frontmatter: catch typos like 'desciption:' or 'argument-hints:'
  # that pass YAML parsing but get silently ignored by Claude Code / Cursor.
  unknown_fields=""
  fields_seen="$(frontmatter "$skill_file" | awk -F: '/^[a-z-]+:/{print $1}' | sort -u)"
  while IFS= read -r fld; do
    [ -z "$fld" ] && continue
    case "$fld" in
      name|description|argument-hint|model|disable-model-invocation|tools|allowed-tools) ;;
      *) unknown_fields="${unknown_fields}${fld} " ;;
    esac
  done <<EOF_FIELDS
$fields_seen
EOF_FIELDS
  if [ -z "$unknown_fields" ]; then
    ok "[$name] frontmatter fields all recognised"
  else
    bad "[$name] unknown frontmatter field(s): ${unknown_fields}— typo or non-portable extension"
  fi

  fm_disable="$(read_field "$skill_file" disable-model-invocation)"

  if [ -z "$fm_desc" ]; then
    bad "[$name] frontmatter missing 'description:'"
  else
    # 3: description length 30..500, single line
    desc_len="${#fm_desc}"
    if [ "$desc_len" -lt 30 ] || [ "$desc_len" -gt 500 ]; then
      bad "[$name] description length ${desc_len} outside [30,500]"
    else
      ok "[$name] description length OK ($desc_len)"
    fi

    # 4: description contains a trigger phrase. Skipped when the skill
    # opts out of model invocation (it's invoked by name, not by trigger).
    if [ "$fm_disable" = "true" ]; then
      ok "[$name] trigger phrase not required (disable-model-invocation)"
    elif printf '%s' "$fm_desc" | grep -qiE 'use (when|before|at|after|during|for)|when (user|the user|you)'; then
      ok "[$name] description has trigger phrase"
    else
      bad "[$name] description missing trigger phrase (e.g. 'Use when …')"
    fi
  fi

  # 5: relative .md links resolve
  link_targets="$(grep -oE '\]\(([^):]+\.md)\)' "$skill_file" | sed -E 's/^\]\(//; s/\)$//' || true)"
  missing_links=""
  if [ -n "$link_targets" ]; then
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      case "$target" in
        http*|/*) continue ;;  # external or absolute (not asserted here)
        *\<*|*\>*) continue ;; # placeholder template like `<date>` — not a real link
      esac
      resolved="$skill_dir/$target"
      if [ ! -f "$resolved" ]; then
        missing_links="${missing_links}${target} "
      fi
    done <<< "$link_targets"
  fi
  if [ -n "$missing_links" ]; then
    bad "[$name] unresolved .md links: $missing_links"
  else
    ok "[$name] relative links resolve"
  fi

  # 6: no unexpanded $AI_KIT_ROOT in code blocks (the variable name is fine in prose,
  # but a bare $AI_KIT_ROOT/... that the reader is supposed to *evaluate* is fine too —
  # we only care about literally broken placeholders like {{AI_KIT_ROOT}}).
  if grep -qE '\{\{[A-Z_]+\}\}' "$skill_file"; then
    bad "[$name] contains unresolved {{PLACEHOLDER}} tokens"
  else
    ok "[$name] no unresolved placeholders"
  fi

  # 7: no tab characters, no CRLF
  if grep -qP '\t' "$skill_file" 2>/dev/null || grep -q $'\t' "$skill_file"; then
    bad "[$name] contains tab characters"
  else
    ok "[$name] no tab characters"
  fi
  if file "$skill_file" 2>/dev/null | grep -qi 'CRLF'; then
    bad "[$name] CRLF line endings"
  else
    ok "[$name] LF line endings"
  fi

  # 8: skill has at least one ## heading describing its procedure,
  # unless it's deliberately short (<20 lines — e.g. zoom-out).
  line_count="$(wc -l < "$skill_file" | tr -d ' ')"
  if [ "$line_count" -lt 20 ]; then
    ok "[$name] short skill — process heading not required"
  elif grep -qE '^## ' "$skill_file"; then
    ok "[$name] has at least one ## heading"
  else
    bad "[$name] longer than 20 lines but has no ## heading"
  fi
done

# Per-fixture checks
if [ -d "$PROMPTS_DIR" ]; then
  echo ""
  echo "=== eval fixture coverage ==="
  echo ""
  missing_coverage=0
  for skill_dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$skill_dir")"
    if [ -d "$PROMPTS_DIR/$name" ] && [ -n "$(find "$PROMPTS_DIR/$name" -name '*.md' -type f 2>/dev/null | head -1)" ]; then
      ok "[$name] has ≥1 fixture"
    else
      bad "[$name] missing eval fixture — add tests/eval/prompts/$name/<scenario>.md"
      missing_coverage=$((missing_coverage + 1))
    fi
  done

  echo ""
  echo "=== eval prompt fixtures ==="
  echo ""
  fixture_count=0
  for fx in $(find "$PROMPTS_DIR" -name '*.md' -type f 2>/dev/null | sort); do
    fixture_count=$((fixture_count + 1))
    rel="${fx#$PROMPTS_DIR/}"
    skill_from_dir="$(dirname "$rel")"
    fm_skill="$(read_field "$fx" skill)"
    fm_id="$(read_field "$fx" id)"

    if [ -z "$fm_id" ]; then
      bad "[fixture $rel] missing id:"
    fi
    if [ -z "$fm_skill" ]; then
      bad "[fixture $rel] missing skill:"
    elif [ "$fm_skill" != "$skill_from_dir" ]; then
      bad "[fixture $rel] skill '$fm_skill' != parent dir '$skill_from_dir'"
    else
      ok "[fixture $rel] skill matches dir"
    fi

    # expects[] non-empty: check at least one '- ' bullet under expects:
    if frontmatter "$fx" | awk '/^expects:/{flag=1; next} /^[A-Za-z_]+:/{flag=0} flag && /^[[:space:]]+- /' | grep -q .; then
      ok "[fixture $rel] expects[] has entries"
    else
      bad "[fixture $rel] expects[] empty"
    fi
  done
  echo ""
  echo "Fixtures scanned: $fixture_count"
fi

echo ""
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
