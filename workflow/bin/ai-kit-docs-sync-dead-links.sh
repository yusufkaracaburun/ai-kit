#!/usr/bin/env bash
# Detect dead markdown links — `[text](path)` only.
#
# Scope (locked from #88 grilling — DO NOT EXPAND in v1):
#   * Only inline markdown links `[text](path)` parsed via regex.
#   * NEVER scan HTML <a href=...>, bare URLs, or reference-style links.
#   * Anchor fragments (`#section`) are NEVER validated — strip before path check.
#   * Targets matching scheme (http:, https:, ftp:, mailto:, etc.) skipped as external.
#   * Relative paths resolve against the markdown file's directory.
#   * Absolute paths (`/foo`) resolve against the project root.
#
# Exit codes:
#   0 — no broken links found
#   1 — one or more broken links
#   2 — error (project path missing, etc.)
#
# Never auto-edits files. Fix-suggestion prompt is opt-in, suppressed under
# --no-prompt or when stdin is not a TTY.
set -uo pipefail

PROJECT_PATH=""
NO_PROMPT=0

for arg in "$@"; do
  case "$arg" in
    --no-prompt) NO_PROMPT=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "dead-links: project path does not exist: $PROJECT_PATH" >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

[ -t 0 ] || NO_PROMPT=1

# Find markdown files. Honour standard exclude dirs.
MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$PROJECT_PATH" \
  -type d \( \
    -name '.git' -o -name 'node_modules' -o -name 'vendor' \
    -o -name '.tmp' -o -name 'dist' -o -name 'build' \
    -o -name '.next' -o -name '.turbo' -o -name '.cache' \
  \) -prune -o \
  -type f -name '*.md' -print | sort)

if [ "${#MD_FILES[@]}" -eq 0 ]; then
  echo "dead-links: no markdown files found — clean."
  exit 0
fi

# Findings: array of `<md_file>|<line_no>|<link_text>|<raw_target>|<resolved_path>`
FINDINGS=()

is_external_url() {
  # http: https: ftp: mailto: tel: data: anything with `:` before any `/`
  case "$1" in
    http://*|https://*|ftp://*|ftps://*|mailto:*|tel:*|data:*|sms:*|file://*) return 0 ;;
  esac
  # generic scheme: starts with [a-z]+: (no spaces or slashes before `:`)
  if printf '%s' "$1" | grep -qE '^[a-zA-Z][a-zA-Z0-9+.-]*:'; then
    return 0
  fi
  return 1
}

# Extract markdown links per file. Use python for robust non-greedy matching +
# correct handling of escaped brackets / nested parens. Bash regex is too fragile.
extract_and_check() {
  local md_file="$1"
  local md_dir
  md_dir="$(dirname "$md_file")"

  python3 - "$md_file" "$md_dir" "$PROJECT_PATH" <<'PY'
import os
import re
import sys

md_file, md_dir, project_root = sys.argv[1], sys.argv[2], sys.argv[3]

# Inline markdown link: [text](target)
# - text: balanced [...] (no nested brackets handled — markdown spec discourages anyway)
# - target: greedy up to closing `)` not preceded by `\`
# Reference-style [text][ref] and bare URLs are intentionally NOT matched.
# Image links ![alt](src) are NOT matched (start with `!`).
LINK_RE = re.compile(r'(?<!\!)\[([^\]]+)\]\(([^)\s]+(?:\s+"[^"]*")?)\)')

with open(md_file, 'r', encoding='utf-8', errors='replace') as fh:
    in_code_fence = False
    for line_no, line in enumerate(fh, start=1):
        # Skip fenced code blocks — links inside ``` ``` are not navigable.
        stripped = line.lstrip()
        if stripped.startswith('```') or stripped.startswith('~~~'):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue
        for m in LINK_RE.finditer(line):
            text = m.group(1)
            raw_target = m.group(2)
            # Strip optional title: "..."
            target = raw_target.split(' ', 1)[0]
            # External URL → skip.
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:', target):
                continue
            # Pure anchor → skip (anchor validation is out-of-scope).
            if target.startswith('#') or target == '':
                continue
            # Strip query + anchor for filesystem check.
            target_path = target.split('#', 1)[0].split('?', 1)[0]
            if target_path == '':
                continue
            # Resolve.
            if target_path.startswith('/'):
                resolved = os.path.normpath(os.path.join(project_root, target_path.lstrip('/')))
            else:
                resolved = os.path.normpath(os.path.join(md_dir, target_path))
            if not os.path.exists(resolved):
                # Print pipe-delimited; bash reads back.
                # Pipes inside text get encoded as %7C.
                safe_text = text.replace('|', '%7C').replace('\n', ' ').strip()
                safe_target = target.replace('|', '%7C')
                rel_resolved = os.path.relpath(resolved, project_root)
                print(f"{md_file}|{line_no}|{safe_text}|{safe_target}|{rel_resolved}")
PY
}

for md in "${MD_FILES[@]}"; do
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    FINDINGS+=("$row")
  done < <(extract_and_check "$md")
done

if [ "${#FINDINGS[@]}" -eq 0 ]; then
  echo "dead-links: 0 broken links across ${#MD_FILES[@]} markdown files — clean."
  exit 0
fi

echo "dead-links: ${#FINDINGS[@]} broken link(s) found:"
echo ""
for row in "${FINDINGS[@]}"; do
  md_file="${row%%|*}"; rest="${row#*|}"
  line_no="${rest%%|*}"; rest="${rest#*|}"
  text="${rest%%|*}"; rest="${rest#*|}"
  target="${rest%%|*}"
  resolved="${rest##*|}"
  rel_md="${md_file#$PROJECT_PATH/}"
  printf '  %s:%s\n    [%s](%s) → missing path: %s\n' "$rel_md" "$line_no" "$text" "$target" "$resolved"
done
echo ""

# Fix-suggestion prompt — opt-in, suppressed under --no-prompt / non-TTY.
if [ "$NO_PROMPT" -eq 0 ]; then
  printf 'Show per-finding fix suggestions? [y/N] '
  read -r reply || reply=""
  if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
    echo ""
    echo "Fix suggestions (manual — docs-sync never auto-edits markdown):"
    for row in "${FINDINGS[@]}"; do
      md_file="${row%%|*}"; rest="${row#*|}"
      line_no="${rest%%|*}"; rest="${rest#*|}"
      text="${rest%%|*}"; rest="${rest#*|}"
      target="${rest%%|*}"
      rel_md="${md_file#$PROJECT_PATH/}"
      printf '  Open %s at line %s — either repoint `[%s](%s)` or delete the reference.\n' \
        "$rel_md" "$line_no" "$text" "$target"
    done
    echo ""
  fi
fi

exit 1
