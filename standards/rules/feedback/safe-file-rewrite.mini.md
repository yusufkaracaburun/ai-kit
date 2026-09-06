---
name: safe-file-rewrite
description: Never redirect into a file you are reading; a pipeline's exit status hides upstream failure and the redirect truncates the target before you notice
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Safe file rewrite

`cmd "$f" | filter > "$f"` destroys `$f`. So does the two-step version
that looks safer:

```bash
grep -v "$line" "$f" | awk '...' > /tmp/out && cat /tmp/out > "$f"   # WRONG
```

A pipeline exits with the status of its **last** command. If `grep`
fails, `awk` still reads empty input and exits 0, the `&&` proceeds, and
`cat` writes nothing over the original. Exit 0, file gone.

## Why

Two failure modes compound, and each is silent on its own.

- **Hidden upstream failure.** `set -o pipefail` fixes the pipeline case.
  A brace group `{ ...; awk ...; }` it does not: the group's status is
  the last command in it, so an `awk` failure in the middle stays
  invisible even under `set -e`.
- **Option-eating patterns.** A pattern starting with `-` is parsed as a
  flag. `grep -vxF "- [item](f.md)"` fails on ugrep and some BSD builds
  with "invalid option". Always pass `--` before user-shaped data.

## How to apply

```bash
set -euo pipefail                          # pipefail is the half people forget

tmp="$(mktemp)"
grep -v -- "$pattern" "$f" > "$tmp"        # -- stops option parsing
[ -s "$tmp" ] || { rm -f "$tmp"; echo "refusing to write empty $f" >&2; exit 1; }
mv "$tmp" "$f"                             # replace only after the guard
```

Validate the format rather than just non-emptiness when the file has one
(`jq empty`, `python3 -c 'import json...'`). And for editing a
known-shape file, prefer an `Edit`-style targeted replace or a `python3`
read-modify-write over a shell pipeline: it fails loudly and never
half-writes.

## When to skip

- Appending (`>> "$f"`) — no truncation risk.
- Generating a file from scratch where empty output is a legitimate result.
- A pipeline already validating its output before it commits, as
  `bin/recommend-rules-cache.sh` does with a JSON parse.

## See also

- `standards/rules/feedback/bsd-sed-word-boundary.mini.md` — the other
  silent shell-portability failure.
