---
name: bsd-sed-word-boundary
description: macOS / BSD sed does not support \b for word boundaries; use [[:<:]] / [[:>:]], grep -w, perl, or awk instead
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: medium
repo_age_min_years: 0
---
# BSD sed word boundary gotcha

`\b` in sed is a GNU extension. On macOS (BSD sed) it matches nothing — silently: exit 0, no lines replaced, the bug hides until someone notices the unchanged file. Portable scripts use `perl -pi -e 's/\bfoo\b/bar/g'` (`\b` works everywhere, preinstalled on both); a match without replacement uses `grep -w`; BSD-only `sed -E 's/[[:<:]]foo[[:>:]]/bar/'`, GNU-only `\<foo\>`; or `gsed` (`brew install gnu-sed`, document the dependency). `\b` is fine only in a script that is explicitly GNU-only (Linux CI, gnu-sed image) — say so in a comment.
