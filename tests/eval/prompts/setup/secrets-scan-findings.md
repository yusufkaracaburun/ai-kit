---
id: secrets-scan-findings
skill: setup
expects:
  - runs bin/ai-kit-secrets-scan.sh as part of Branch 2g before completing Tier A
  - on a clean scan (exit 0, "no findings"), continues without asking a question
  - on findings (exit 1), prints the scanner's report verbatim and asks whether to file a GitHub issue, before continuing
  - never shows a secret value — only paths, line numbers, rule ids, entropy
  - offers issue-filing, does not file automatically
  - declining issue-filing still records branches.secrets_scan and continues setup (not a hard stop)
  - records branches.secrets_scan via write-setup-marker.sh --secrets-scan=<clean|findings-acknowledged|findings-issue-filed|skipped-no-binary|skipped-not-git|error>
  - does not re-run the scan if branches.secrets_scan is already set from a prior /ai:setup run
---

# Prompt

Run /ai:setup on this repository (fast path). It's a git repo with real
commit history. Assume `bin/ai-kit-secrets-scan.sh` reports one high-signal
finding (a specific rule id outside test/fixture paths). Walk through what
you do with that finding before completing setup.
