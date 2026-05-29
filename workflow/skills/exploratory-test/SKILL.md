---
name: exploratory-test
description: Human-driven manual review / exploratory testing — tester emits 50-100+ free-form findings across roles / apps / pages, skill acks each, then bundles into one parent GH issue per scope (checklist + repro + cross-refs). Use when a tester tests through an app and wants one tidy parent issue instead of issue-explosion. Triggers: "exploratory test", "manual review", "doorlopen en bugs loggen", or `/ai:exploratory-test`.
---

Run a long human-driven exploratory testing session. The tester emits free-form findings ("X is too big", "Y is missing"), the skill logs them with one short acknowledgement per finding, and at the end normalizes + publishes one clean parent issue per scope.

This is **not** the same as `/ai:qa` (automated smoke test against a URL) or `/ai:diagnose` (one hard bug). It is the missing primitive between "tester observes" and "issue tracker has actionable parent-issue".

## Why this shape

Proven 2026-05-28 on naschool: 89 findings across 4 roles on 2 hosts, 2-3 hours, ended with 2 clean parent-issues (`naschool#81`, `naschool#82`) + 1 follow-up + 1 cross-repo backlog issue. The defaults below all come from that run; deviating from them degenerates the experience.

Three failure modes this skill prevents:

1. **Issue-explosion** — `gh issue create` per finding mid-session kills tempo and floods the tracker.
2. **Forgetting findings** — capturing in a notes app loses cross-app + cross-role context.
3. **Lost triage opportunities** — bundling later is painful when findings sit across different scopes.

## Defaults (don't deviate without explicit reason)

- **Capture-only.** No diagnose, no lookup, no severity-guess during capture — breaks tester's flow.
- **Free-form > template.** Strict templates kill tempo; the skill normalizes at end.
- **One short ack per finding.** Not silent (feels broken), not paragraphs (clutter). Format: `#N [scope] <one-line>. Gelogd.`
- **Per-scope bundling.** New host or app → new parent issue with matching `area/*` label. Same scope → append to existing parent.
- **NL by default for `--lang nl` users**, EN for `--lang en`. Ack language matches.

## Phase 1 — start of session (single `AskUserQuestion`)

Ask 4 questions in one `AskUserQuestion` call (each multi-select=false):

1. **Scope-markers style** — how the tester signals app/role shifts.
   - User-controlled (`Start <app> testen` / `Stop <app> testen`) **(Recommended)**
   - Fixed-scope (single app, single role for the whole session)

2. **Issue-structuur** — how findings bundle into issues.
   - One parent per scope-shift (new host / app → new parent) **(Recommended)**
   - One parent per session
   - One issue per finding (rare — only when each finding is already triage-ready)

3. **Capture-mode** — what the assistant does during capture.
   - Free-form (assistant normalizes at end) **(Recommended)**
   - Strict template (tester provides repro/expected/actual per finding)
   - Live-log to file (write each finding to a markdown file as it comes in)

4. **Hulp-mode** — assistant's role during capture.
   - Capture-only **(Recommended)**
   - Capture + lookup (assistant fetches docs when asked, no diagnose)
   - Capture + diagnose (assistant proposes root cause inline — only if tester explicitly wants distraction)

Record the choices in working memory for the rest of the session. Do not re-ask.

## Phase 2 — capture loop

This is the bulk of the session — minutes to hours. Tester emits free-form findings in chat.

For each finding from the tester:
- Assign sequential `#N`.
- Detect current scope from the latest scope-marker (`ik ben nu op http://...`, `Start admin.naschool testen`, `Stop demo.naschool testen`, role announcements).
- Reply with **one line, nothing else**:
  ```
  #N [scope] <normalized one-line>. Gelogd.
  ```
- Maintain internal state:
  - Findings list: `{nr, scope, host, role, page, raw, ack, tag_guess, related_to: [N...]}`
  - Scope-marker history (timestamps of host/role/page shifts).

Hard rules during capture:
- **No diagnose** unless hulp-mode = `capture + diagnose`.
- **No lookups** unless hulp-mode = `capture + lookup` AND tester asked.
- **No severity guess** — that happens in Phase 3.
- **No batch summaries** — never "so far we have N findings of which …". Tester loses tempo reading meta-talk.
- **Scope-shifts are first-class events** — log them inline silently, do not ack them as findings.

Honour pause/resume: after `klaar` (end-trigger), if tester says `ik ben nu op …` instead of confirming bundle, the session continues. Bundle creation only fires on the next genuine end-trigger.

End-trigger words (case-insensitive):
- NL: `klaar`, `stop`, `bundel naar github`, `bundel het`, `maak de issue`
- EN: `done`, `wrap up`, `bundle to github`, `bundle it`, `create the issue`

## Phase 3 — normalize at end

When an end-trigger fires:

1. Show a numbered overview table to the tester:
   ```
   | # | scope         | one-line                              | tag    |
   |---|---------------|---------------------------------------|--------|
   | 1 | demo · ouder  | Inschrijfknop verdwijnt op mobile     | bug    |
   | 2 | demo · ouder  | "Plaatsen" copy onduidelijk           | copy   |
   ```
2. Propose `repro / expected / actual / tag` per finding. Pull repro from the raw text the tester gave; mark `<auto-filled, verify>` when guessed.
3. Tag set kept small: `bug | ux | copy | feature | open-question | a11y | perf | security | design-system | refactor`. No others.
4. **Open-questions are first-class findings.** "How do we model X?" gets logged alongside "button is too big" — both belong in the parent.
5. **Cross-references cluster.** Findings touching the same root cause (Jaccard ≥0.4 on tokenised one-liners, OR shared page-path, OR tester said "zelfde als #N") get a `## Cross-references` section at the bottom: `#3 ↔ #11 ↔ #54` style. Don't overdo it — a cluster with only one ↔ pair is noise, skip.
6. Ask tester to confirm the overview before publishing. Single yes/no, no per-finding gate (that's phase-2 triage's job).

## Phase 4 — publish

When the tester confirms:

1. **Detect available labels** via `gh label list --json name --limit 200`. Never auto-create labels — fall back to whatever exists. Required matches in priority order: `area/<scope>` (if scope maps to one), `needs-triage`, `P0-P3` (don't pre-assign — that's triage), language flag if convention exists.
2. **Title pattern:** `Exploratory testing — <YYYY-MM-DD> — <host> (<rollen>)`.
3. **Body structure:**
   ```markdown
   ## Sessie
   - Tester: <gh-user>
   - Datum: YYYY-MM-DD
   - Host(s): <host>
   - Rollen: <rol1>, <rol2>

   ## Findings (N)
   - [ ] #1 [scope] one-line
   - [ ] #2 [scope] one-line
   ...

   ## Details per finding
   ### #1 — one-line
   - **Scope:** <host> · <rol> · <page>
   - **Repro:** <steps>
   - **Expected:** <expected>
   - **Actual:** <actual>
   - **Tag:** bug
   - **Raw:** <tester's original text>
   ...

   ## Cross-references
   - Root-cause cluster A: #3 ↔ #11 ↔ #54 — verdwijnende inschrijfknop op mobile
   - Root-cause cluster B: #7 ↔ #22 — copy "plaatsen" onduidelijk in 2 contexten

   ## Open questions
   - #14, #41 — vragen voor product
   ```
4. **One `gh issue create` per scope.** If session spanned hosts, one parent per host, each with its own `area/*` label. Cross-link the parents (`Related: #N`) in each body.
5. Echo issue URLs back to the tester.

## Phase 5 — hand off to phase-2 triage

Per checkbox in the parent issue, the tester (later) picks:
- **Fix-now** → commit directly (small fixes, no sub-issue).
- **Sub-issue** → `gh sub_issue_write` OR `/ai:to-issues` (use `/ai:to-issues` when finding is a tracer-bullet slice).
- **Verwerpen** → check the box with `~strikethrough~` and a one-line why.
- **Dedupe** → check + `Duplicate of #N` comment.

Do not run phase-2 inside this skill. The whole point of capture-and-bundle is to make phase-2 a separate, lower-stakes pass.

## Flags

- `--mode=capture-only|with-lookup|with-diagnose` — overrides Phase-1 Q4 default. Default `capture-only`.
- `--bundle=per-session|per-scope|per-finding` — overrides Phase-1 Q2 default. Default `per-scope` when host changes during the session, `per-session` otherwise.
- `--lang=nl|en` — language of ack lines + issue body. Default `nl` for users whose previous sessions ran in Dutch (heuristic: most recent ai-kit conversation language), else `en`.
- `--dry-run` — runs Phase 1-3 and prints the would-be issue body to chat without calling `gh issue create`. Useful for testing the skill against a stub session.

## Anti-patterns (don't do these)

- Acking with anything other than the one-line `#N [scope] ... Gelogd.` form. Anything else clutters.
- Proposing fixes during capture. Even when the fix is obvious. The tester loses tempo.
- Asking for repro details mid-capture. Phase 3 collects them.
- Auto-creating labels. Always fall back to existing labels; surface "no `area/*` label exists — using `needs-triage` only" if needed.
- Posting >1 GH issue without explicit scope-shift signal. Per-finding posting is the default failure mode this skill prevents.
- Re-asking Phase-1 questions mid-session. State carries forward.

## Cross-references in the ai-kit ecosystem

- `/ai:review` — pre-merge code review on the branch diff. Static-code angle of "review"; this skill is the **human-driven UI/UX manual review** angle. Use `/ai:review` before merging code; use this skill when a human is clicking through the running app.
- `/ai:qa` — automated smoke test against a URL. Different shape: assistant drives the browser, not the tester.
- `/ai:diagnose` — one hard bug, reproduce-minimise-instrument loop.
- `/ai:triage` — phase-2 per-issue state-machine; assumes issues already exist.
- `/ai:to-issues` — splits a plan into tracer-bullet slices; assumes a plan, not raw observations.

## Manual-run reference (proof + design rationale)

The skill defaults all come from a manual session 2026-05-28 on naschool — the user emitted 89 findings across 4 roles on 2 hosts in 2-3 hours, ending with:
- naschool#81 — 72 findings, 3 rollen, ouder/gast/schooladmin op demo.naschool, `area/portal`
- naschool#82 — 17 findings, 2 rollen, central_admin + schoolbestuur op admin.naschool, `area/admin`
- naschool#83 — follow-up todo voor 3 nog-te-doen rol-sessies, `P1-high`
- naschool#84 — design-system tracker dat opkwam tijdens sessie, `P0-critical`

Plan file from that run: `naschool/.agents/plans/ik-wil-nu-handmatige-lively-rainbow.md`.
