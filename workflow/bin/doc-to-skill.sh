#!/usr/bin/env bash
# Convert a PDF / EPUB / DOCX / RTF / ODT / MD into a SKILL.md scaffold.
#
# Usage:
#   bin/doc-to-skill.sh <source-file> [--name <slug>] [--target <dir>]
#
# Output:
#   <target-dir>/<slug>/SKILL.md   — scaffold with frontmatter,
#                                    chapter index, claim placeholders,
#                                    sources list, provenance credit.
#
# Defaults:
#   <slug>       basename of the source file, lowercased, non-alnum → "-"
#   <target-dir> ./skills (creates if missing); fall back to
#                workflow/skills when run from inside ai-kit itself.
#
# Trust model:
#   - Read-only on the source document.
#   - Writes one new directory + SKILL.md; refuses to overwrite an
#     existing SKILL.md at the target path.
#   - Pure scaffold — the user / agent fills in real claims afterwards
#     from the chapter index pointers.
#
# Dependency: pandoc (system install). No new repo-level deps.
# Provenance: extraction pattern adapted from virgiliojr94/book-to-skill
# (MIT). ai-kit ports only the structural scaffold; PKM-vault bits
# (wiki/summaries writes, commit hooks, eod/) are intentionally dropped.

set -euo pipefail

SRC=""
SLUG=""
TARGET_DIR=""

usage() {
  cat <<'USAGE'
Usage: bin/doc-to-skill.sh <source-file> [--name <slug>] [--target <dir>]

Converts a single document (PDF/EPUB/DOCX/RTF/ODT/MD) into a SKILL.md
scaffold with chapter index, claim placeholders, sources, and
provenance credit.

Options:
  --name <slug>     Skill directory name. Default: source-basename-slugified.
  --target <dir>    Output root. Default: ./skills (or workflow/skills
                    when running inside the ai-kit repo).
  -h, --help        This help.

Requires pandoc on PATH.
USAGE
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --name)   SLUG="${2:-}"; shift 2 ;;
    --name=*) SLUG="${1#*=}"; shift ;;
    --target)   TARGET_DIR="${2:-}"; shift 2 ;;
    --target=*) TARGET_DIR="${1#*=}"; shift ;;
    --*) echo "Unknown flag: $1" >&2; usage ;;
    *)
      if [ -n "$SRC" ]; then
        echo "Unexpected arg: $1" >&2; usage
      fi
      SRC="$1"; shift
      ;;
  esac
done

[ -z "$SRC" ] && usage
[ -f "$SRC" ] || { echo "Source file not found: $SRC" >&2; exit 2; }

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is required. Install: https://pandoc.org/installing.html" >&2
  exit 2
fi

# Slugify default from source basename.
if [ -z "$SLUG" ]; then
  base="$(basename "$SRC")"
  base="${base%.*}"
  SLUG="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-+|-+$//g')"
fi
[ -z "$SLUG" ] && { echo "Could not derive slug; pass --name <slug>." >&2; exit 2; }

# Default target dir: ./skills (or workflow/skills when in ai-kit repo).
if [ -z "$TARGET_DIR" ]; then
  if [ -d "workflow/skills" ] && [ -f "VERSION" ] && [ -f ".claude-plugin/marketplace.json" ] 2>/dev/null; then
    TARGET_DIR="workflow/skills"
  elif [ -d "workflow/skills" ]; then
    TARGET_DIR="workflow/skills"
  else
    TARGET_DIR="skills"
  fi
fi
mkdir -p "$TARGET_DIR/$SLUG"

OUT="$TARGET_DIR/$SLUG/SKILL.md"
if [ -e "$OUT" ]; then
  echo "Refusing to overwrite existing $OUT" >&2
  exit 2
fi

# Convert to plain markdown via pandoc. Pandoc handles PDF / EPUB / DOCX /
# RTF / ODT / MD natively (PDF needs pdftotext under the hood for old
# pandoc versions; modern pandoc ships its own PDF reader).
TMP="$(mktemp -t doc-to-skill.XXXXXX.md)"
trap 'rm -f "$TMP"' EXIT

# Use --wrap=none so headings stay on one line, easier to grep.
pandoc "$SRC" -t markdown --wrap=none -o "$TMP" 2>/dev/null || {
  echo "pandoc failed on $SRC — try a different format or check the file." >&2
  exit 2
}

# Extract H1/H2 as the chapter index. Pandoc emits ATX-style headers
# (#, ##) by default for --to=markdown.
CHAPTERS="$(grep -E '^#{1,2} ' "$TMP" | head -50 | sed -E 's/^(#{1,2}) (.*)$/- \1 \2/' | sed -E 's/^- # /- /; s/^- ## /  - /')"
[ -z "$CHAPTERS" ] && CHAPTERS="- (no headings detected — pandoc produced flat text; review the source manually)"

# Word count proxy for a fitness signal.
WORDS="$(wc -w < "$TMP" | tr -d ' ')"

SRC_BASENAME="$(basename "$SRC")"
TODAY="$(date -u +%Y-%m-%d)"

cat > "$OUT" <<SKILL
---
name: $SLUG
description: TODO — one-line summary of this skill. Replace with what triggers it.
---

# $SLUG

> Scaffold generated $TODAY by \`bin/doc-to-skill.sh\` from \`$SRC_BASENAME\`
> (~$WORDS words). **This is a stub** — fill in the claims below from the
> chapter index, then refine the frontmatter \`description\` so the skill
> auto-selects on the right prompts.

## Claims

Each claim should quote the source — chapter / section heading or
page reference is fine. Pattern:

> **Claim:** one-sentence assertion. **Source:** \`$SRC_BASENAME\`,
> § <chapter / section heading>.

Replace the placeholders below with real claims from the source. Aim for
5–15 concrete claims; each one should be defensible from the source
material alone.

- **Claim:** TODO. **Source:** \`$SRC_BASENAME\`, § <chapter>.
- **Claim:** TODO. **Source:** \`$SRC_BASENAME\`, § <chapter>.
- **Claim:** TODO. **Source:** \`$SRC_BASENAME\`, § <chapter>.

## Chapter index

Captured from the source's heading structure. Use this as the navigation
when filling the claims above.

$CHAPTERS

## Sources

- \`$SRC_BASENAME\` — source document (path captured at scaffold time:
  \`$SRC\`).

## Provenance

- Scaffold pattern adapted from
  [virgiliojr94/book-to-skill](https://github.com/virgiliojr94/book-to-skill)
  (MIT). ai-kit ports only the structural scaffold; PKM-vault bits are
  intentionally dropped.
- Generated by \`bin/doc-to-skill.sh\` on $TODAY.
SKILL

echo "Wrote $OUT"
echo "Next: fill in the Claims section from the Chapter index, then refine the frontmatter 'description'."
