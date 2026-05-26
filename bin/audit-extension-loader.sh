#!/usr/bin/env bash
# Discover audit-architecture extensions that apply to a given project.
#
# Globs workflow/skills/audit-architecture-*/SKILL.md, parses frontmatter,
# intersects each candidate's applies_to.frameworks against the framework
# array from bin/detect-tooling.sh --json. Prints matched SKILL.md paths
# (one per line, filename-sorted).
#
# Env:
#   AI_KIT_AUDIT_NO_EXTEND=1  -> exit 0 with empty stdout (opt-out)
#   AI_KIT_AUDIT_SKILLS_DIR   -> override skills-dir (default: AIKIT/workflow/skills)
#                                Testing hook; not part of the public contract.
#
# Language matching: detect-tooling.sh does not yet emit a languages array,
# so this script derives a minimal language set from the project shape:
#   - typescript: tsconfig.json present
#   - dart:       pubspec.yaml present
# Extensions can match on applies_to.frameworks OR applies_to.languages (union).
#
# Extensions whose frontmatter `extends:` field is missing or not equal to
# `audit-architecture` are rejected with a stderr warning and skipped
# (non-fatal). See standards/contracts/audit-architecture-extension.contract.md.

set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"

usage() {
  echo "Usage: $0 <project-path>" >&2
  exit 2
}

if [ $# -lt 1 ]; then usage; fi

TARGET="$(cd "$1" && pwd)"

if [ "${AI_KIT_AUDIT_NO_EXTEND:-0}" = "1" ]; then
  exit 0
fi

AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
PRIMITIVES="$(resolve_primitives_root "$AIKIT")"
SKILLS_DIR="${AI_KIT_AUDIT_SKILLS_DIR:-$PRIMITIVES/skills}"
PARSER="$SCRIPT_BIN/lib/parse-audit-extension-frontmatter.py"

if [ ! -d "$SKILLS_DIR" ]; then
  exit 0
fi

shopt -s nullglob
CANDIDATES=("$SKILLS_DIR"/audit-architecture-*/SKILL.md)
shopt -u nullglob

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  exit 0
fi

SORTED=()
while IFS= read -r line; do SORTED+=("$line"); done < <(printf '%s\n' "${CANDIDATES[@]}" | sort)

# Detected frameworks + languages: empty is fine — only blocks the
# intersection step, never the structural-validation warnings below.
DETECT_JSON="$(bash "$AIKIT/bin/detect-tooling.sh" "$TARGET" --json 2>/dev/null || echo '{"frameworks":[]}')"
DETECTED_FRAMEWORKS="$(printf '%s' "$DETECT_JSON" | python3 -c 'import json, sys
try:
    d = json.load(sys.stdin)
    for f in d.get("frameworks", []) or []:
        print(f)
except Exception:
    pass' 2>/dev/null || true)"

DETECTED_LANGUAGES=""
[ -f "$TARGET/tsconfig.json" ] && DETECTED_LANGUAGES="$DETECTED_LANGUAGES"$'\n'"typescript"
[ -f "$TARGET/pubspec.yaml" ] && DETECTED_LANGUAGES="$DETECTED_LANGUAGES"$'\n'"dart"
DETECTED_LANGUAGES="$(printf '%s\n' "$DETECTED_LANGUAGES" | sed '/^$/d')"

for candidate in "${SORTED[@]}"; do
  ext_dir="$(dirname "$candidate")"
  ext_name="$(basename "$ext_dir")"

  parsed="$(python3 "$PARSER" "$candidate" 2>/dev/null || true)"
  if [ -z "$parsed" ]; then
    echo "audit-extension-loader: skipping $ext_name (could not parse frontmatter)" >&2
    continue
  fi

  ext_extends="$(echo "$parsed" | grep '^EXTENDS=' | cut -d= -f2-)"
  ext_frameworks="$(echo "$parsed" | grep '^FRAMEWORKS=' | cut -d= -f2-)"
  ext_languages="$(echo "$parsed" | grep '^LANGUAGES=' | cut -d= -f2-)"

  if [ "$ext_extends" != "audit-architecture" ]; then
    echo "audit-extension-loader: skipping $ext_name (extends: '$ext_extends' is not 'audit-architecture')" >&2
    continue
  fi

  if [ -z "$DETECTED_FRAMEWORKS" ] && [ -z "$DETECTED_LANGUAGES" ]; then
    continue
  fi

  matched="false"

  if [ -n "$ext_frameworks" ] && [ -n "$DETECTED_FRAMEWORKS" ]; then
    IFS=',' read -r -a ext_fw_arr <<< "$ext_frameworks"
    while IFS= read -r detected; do
      for ext_fw in "${ext_fw_arr[@]}"; do
        if [ "$detected" = "$ext_fw" ]; then
          matched="true"
          break 2
        fi
      done
    done <<< "$DETECTED_FRAMEWORKS"
  fi

  if [ "$matched" = "false" ] && [ -n "$ext_languages" ] && [ -n "$DETECTED_LANGUAGES" ]; then
    IFS=',' read -r -a ext_lang_arr <<< "$ext_languages"
    while IFS= read -r detected; do
      for ext_lang in "${ext_lang_arr[@]}"; do
        if [ "$detected" = "$ext_lang" ]; then
          matched="true"
          break 2
        fi
      done
    done <<< "$DETECTED_LANGUAGES"
  fi

  if [ "$matched" = "true" ]; then
    printf '%s\n' "$candidate"
  fi
done
