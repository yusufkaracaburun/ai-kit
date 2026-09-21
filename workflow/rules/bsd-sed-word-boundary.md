---
paths: ["**/*.sh"]
---
<!-- ai-kit global rule (ADR-0015): macOS / BSD sed does not support \b for word boundaries; use [[:<:]] / [[:>:]], grep -w, perl, or awk instead -->
<!-- Source: standards/rules/feedback/bsd-sed-word-boundary.mini.md — re-stamp with bin/sync-plugin-rules.sh -->

# BSD sed word boundary gotcha

`\b` in sed is a GNU extension. On macOS (BSD sed) it matches nothing — silently: exit 0, no lines replaced, the bug hides until someone notices the unchanged file. Portable scripts use `perl -pi -e 's/\bfoo\b/bar/g'` (`\b` works everywhere, preinstalled on both); a match without replacement uses `grep -w`; BSD-only `sed -E 's/[[:<:]]foo[[:>:]]/bar/'`, GNU-only `\<foo\>`; or `gsed` (`brew install gnu-sed`, document the dependency). `\b` is fine only in a script that is explicitly GNU-only (Linux CI, gnu-sed image) — say so in a comment.
