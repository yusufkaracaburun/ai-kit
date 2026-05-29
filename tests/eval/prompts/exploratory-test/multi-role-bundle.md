---
id: multi-role-bundle
skill: exploratory-test
expects:
  - opens with a single AskUserQuestion covering scope-markers / issue-structuur / capture-mode / hulp-mode
  - defaults to capture-only + free-form + per-scope bundling + NL acks when user signals Dutch
  - acks each finding with one short line in the form `#N [scope] <one-line>. Gelogd.` — never paragraphs, never diagnose
  - tracks scope-shifts (`ik ben nu op admin.naschool`) silently without acking them as findings
  - does NOT propose fixes or repro details during the capture loop
  - on `bundel naar github` detects available labels via `gh label list` before creating issues (never auto-creates labels)
  - creates one parent GH issue per scope when host changes, not per finding and not one giant cross-host parent
  - parent issue body contains: ## Sessie / ## Findings (N) checklist / ## Details per finding / ## Cross-references / ## Open questions sections
  - hands off to /ai:triage or /ai:to-issues for phase-2 instead of running per-finding triage inside this skill
---

# Prompt

Ik ga nu een uurtje door demo.naschool en daarna door admin.naschool om bugs en UX-issues te loggen. Ik wil free-form typen wat ik tegenkom; jij logt mee. Aan het eind één parent-issue per app op GitHub. Start.
