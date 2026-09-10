---
id: secrets-scan-low-signal
skill: setup
expects:
  - runs bin/ai-kit-secrets-scan.sh as part of Branch 2g before completing Tier A
  - recognizes that low-signal-only findings still exit 0 (not the "no findings" message, but not exit 1 either)
  - does NOT ask the acknowledgement question for this case (exit 0 never asks)
  - still prints the scanner's LOW SIGNAL report to the user (visible, not hidden)
  - records branches.secrets_scan=clean for this case, not skipped-* or an invented value
  - continues setup without pausing
---

# Prompt

Run /ai:setup on this repository (fast path). It's a git repo with real
commit history. Assume `bin/ai-kit-secrets-scan.sh` exits 0 but reports 12
findings across 3 files, all `generic-api-key` low-signal noise (no
high-signal rule outside a fixture/test path). Walk through what you do
with that result before completing setup.
