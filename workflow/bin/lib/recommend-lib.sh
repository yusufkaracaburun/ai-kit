# shellcheck shell=bash
# Score canonical rules in standards/rules/ for relevance to a target project.
#
# Reads:
#   - Rule frontmatter (universal, applies_to.frameworks/architectures, weight, repo_age_min_years)
#   - detect-tooling.sh --json output for the target
#   - git log first-commit date for repo age
#
# Writes (to stdout): newline-separated "rule_name<TAB>score<TAB>reason" rows,
# sorted high→low score. Score 0 rules are filtered.

# Score one rule against a detected context.
# Args: rule_path, frameworks_csv, architectures_csv, repo_age_years
# Echoes: "rule_name<TAB>score<TAB>reason"
_recommend_score_one() {
  local rule_path="$1" fw_csv="$2" arch_csv="$3" age_years="$4"
  local name universal weight age_min frameworks architectures description
  name="$(basename "$rule_path")"
  name="${name%.mini.md}"
  name="${name%.nano.md}"

  universal="$(_emitter_extract_meta "$rule_path" universal)"
  weight="$(_emitter_extract_meta "$rule_path" weight)"
  age_min="$(_emitter_extract_meta "$rule_path" repo_age_min_years)"
  description="$(_emitter_extract_meta "$rule_path" description)"
  frameworks="$(_emitter_extract_list "$rule_path" frameworks)"
  architectures="$(_emitter_extract_list "$rule_path" architectures)"

  local score=0 reason=""
  case "$weight" in
    high)   weight_score=3 ;;
    medium) weight_score=2 ;;
    low)    weight_score=1 ;;
    *)      weight_score=2 ;;
  esac

  if [ "$universal" = "true" ]; then
    score=$weight_score
    reason="universal (weight=${weight:-medium})"
  fi

  local fw match_fw=0
  for fw in ${frameworks}; do
    if [[ ",${fw_csv}," == *",${fw},"* ]]; then
      match_fw=1
      [ -n "$reason" ] && reason="${reason}; "
      reason="${reason}framework match: ${fw}"
      break
    fi
  done
  [ "$match_fw" = 1 ] && score=$((score + 2))

  local arch match_arch=0
  for arch in ${architectures}; do
    if [[ ",${arch_csv}," == *",${arch},"* ]]; then
      match_arch=1
      [ -n "$reason" ] && reason="${reason}; "
      reason="${reason}architecture match: ${arch}"
      break
    fi
  done
  [ "$match_arch" = 1 ] && score=$((score + 2))

  if [ -n "$age_min" ] && [ "$age_min" != "0" ]; then
    if [ -n "$age_years" ] && [ "$age_years" -ge "$age_min" ] 2>/dev/null; then
      score=$((score + 1))
      [ -n "$reason" ] && reason="${reason}; "
      reason="${reason}repo age ${age_years}y ≥ ${age_min}y"
    elif [ "$universal" != "true" ] && [ "$match_fw" = 0 ] && [ "$match_arch" = 0 ]; then
      # Non-universal rule with age requirement not met → suppress
      score=0
      reason="repo too young (<${age_min}y)"
    fi
  fi

  [ -z "$reason" ] && reason="no signals"
  printf "%s\t%d\t%s\t%s\n" "$name" "$score" "$weight" "$reason"
}

# Recommend rules for a target project.
# Args: aikit_root, target_project_path
# Echoes sorted "name<TAB>score<TAB>weight<TAB>reason" rows (score > 0).
recommend_rules() {
  local aikit_root="$1" target="$2"
  local rules_dir="$aikit_root/standards/rules"

  # Detect frameworks + architectures via detect-tooling.sh JSON.
  local json fw_csv="" arch_csv=""
  json="$("$aikit_root/bin/detect-tooling.sh" "$target" --json 2>/dev/null || echo '{}')"

  fw_csv="$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(",".join(d.get("frameworks", [])))
except Exception:
    print("")
')"
  arch_csv="$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    a = d.get("architecture", {})
    parts = []
    fe = a.get("frontend", {}).get("detected", "")
    be = a.get("backend", {}).get("detected", "")
    if fe: parts.append(fe)
    if be: parts.append(be)
    print(",".join(parts))
except Exception:
    print("")
')"

  # Repo age in years.
  local age_years=0
  if [ -d "$target/.git" ]; then
    local first_commit
    first_commit="$(git -C "$target" log --reverse --format=%at 2>/dev/null | head -1)"
    if [ -n "$first_commit" ]; then
      local now epoch_diff
      now="$(date +%s)"
      epoch_diff=$((now - first_commit))
      age_years=$((epoch_diff / 31536000))
    fi
  fi

  local results=""
  for f in "$rules_dir"/*.mini.md "$rules_dir"/*.nano.md \
           "$rules_dir"/feedback/*.mini.md "$rules_dir"/feedback/*.nano.md; do
    [ -f "$f" ] || continue
    local row
    row="$(_recommend_score_one "$f" "$fw_csv" "$arch_csv" "$age_years")"
    results="${results}${row}"$'\n'
  done

  # Sort by score desc, filter zero scores.
  printf "%s" "$results" | awk -F'\t' 'NF>=3 && $2+0>0' | sort -t$'\t' -k2,2nr -k3,3
}
