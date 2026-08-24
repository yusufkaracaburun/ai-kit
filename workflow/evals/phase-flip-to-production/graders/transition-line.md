---
type: regex
target: last_message
pattern: 'lifecycle:\s*development\s*(→|->)\s*production'
match: contains
---

The script's "lifecycle: development → production" transition line must be
surfaced to the user verbatim.
