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

The `\b` word-boundary escape is a GNU extension. On macOS (BSD sed)
and on most non-Linux platforms, `\b` either matches a literal backspace
or matches nothing — silently. Scripts that work on Linux CI fail
quietly on a macOS dev machine, and vice-versa.

## Why

Silent regex failure is the worst kind of failure: the script reports
exit 0, no lines are replaced, and the bug hides until a developer
notices the unchanged file. The fix is one of three swaps; the cost is
remembering to make it.

## How to apply

Pick whichever is shortest:

```bash
# 1) POSIX bracket expressions — work on BSD and GNU sed alike
sed -E 's/[[:<:]]foo[[:>:]]/bar/' file        # BSD only
sed -E 's/\<foo\>/bar/' file                  # GNU only

# 2) grep -w when you just want a match, not a replacement
grep -w foo file

# 3) perl one-liner — \b works everywhere
perl -pi -e 's/\bfoo\b/bar/g' file

# 4) awk word match
awk '$0 ~ /^|[^[:alnum:]_]foo([^[:alnum:]_]|$)/'
```

For portable scripts that must work on both Linux and macOS, **prefer
`perl -pi -e`**. It supports `\b` consistently and is preinstalled on
both. If `perl` is not available, use `gsed` (`brew install gnu-sed`)
on macOS and document the dependency.

## When to skip

- The script is explicitly GNU-only and runs on a GNU userland (Linux
  CI, Docker image with `gnu-sed`). Then `\b` is fine; document the
  assumption with one comment in the script.
- You're using `grep` / `ripgrep` / `awk` to begin with — those have
  their own word-boundary syntax.

## See also

- `man re_format` on macOS — POSIX bracket-expression docs.
