---
name: design-to-code
description: Turn a Paper design into code and prove the code still matches it, design → audit → build → prove against a Paper frame read through the Paper MCP, plus store slides. Use when the user says "design naar code", "bouw dit scherm uit het design", "klopt de code met het design", "design sync", "parity check", "store screenshots", "App Store screenshots", "Play Store screenshots", after a Paper design change, or via /ai:design-to-code. Not for choosing a visual direction.
---

# Design to code

The design file is the source of truth. Code follows it; drift is a finding, never a taste difference. Five flows — design, audit, build, prove, store — run one screen at a time or a whole module in batch.

Stack-agnostic: this skill carries the procedure, the bar, and the delegation shape. Project specifics — token names, route language, frame ids, the project's own gates — are an overlay the project keeps in its own `.agents/skills/` (or `.claude/skills/`); they do not belong here.

## Step 0 — precondition and ownership

1. **Reference present?** Either a Paper design with the Paper MCP reachable, which means a `list_resources` call succeeds (the `mcp__paper__*` tools load even when the desktop app is closed; a failed call → stop with its message), or a reference image (a block thumbnail, an approved screenshot) for `image` mode. Nothing → stop. When the question is *which* direction, do the UI work inline; do not invent a design and call it parity. Design files from an older tool are a read-only archive, not a source.
2. **Repo already owns this job?** `ls .claude/skills/ .agents/skills/ 2>/dev/null` — a project-local design/Paper skill outranks this one. Load it, follow it, say so in the report. Only continue below when none exists.

### The project overlay

The overlay is a pointer file, not a second copy of this skill. It carries what only the project knows; a build that has to ask for any of these mid-unit was handed an incomplete overlay:

- **Frame → route map** and **design element → component map** (which element on the Paper components page is which code component). An element with no code component yet is a component task first.
- **State recipe per screen** — the exact app state the frame shows, as data: which account, which record, which time; plus how to reach it (a fixture, an E2E helper, a mock endpoint). Reaching the state is the cost of the live compare, not the screenshot.
- **All states**, not the happy one: loading, empty, error; the ones a static reference cannot show go in `undesigned_states`.
- **Copy per locale** — a frame usually carries one language; the others must not be invented on the code side each time.
- **Interactions** — tap targets and where they go, sheet rows, gestures.
- **Viewports and devices** the live step uses: `breakpoints`.
- **Pointers** to the project's gate doc and ADRs; the overlay never restates them.

The values the judge reads live in one fixed file, `.agents/design-to-code.overlay.json`:

```json
{
  "bar": 100,
  "tolerance": 0,
  "breakpoints": [375, 1280],
  "themes": ["light", "dark"],
  "undesigned_states": { "<unit>": ["hover", "focus"] },
  "tasks": [{ "name": "", "unit": "<id>", "route": "", "max": 3 }],
  "units": { "<id>": { "route": "", "reference": { "mode": "image", "files": [], "values": "" }, "paths": [], "mask": [], "pin": "" } }
}
```

Paper mode uses `"reference": { "mode": "paper", "frame": "<id>" }`. Only `themes` with one entry, `mask` or `undesigned_states` empty, and no task naming this unit mean does not apply; any other empty value is FAIL not configured. A missing key is FAIL not configured. Only `bar` and `tolerance` have defaults. `approved_at` and `mask` are optional; no item needs them. `mask` lists CSS selectors (the click log's `<selector>` is CSS too) for elements whose value changes on every load (a random reference, a date, an id): the lead covers those elements with a flat box in both the reference and the build screenshot before the comparison, and the judge lists the masked CSS selectors in its Render vs reference evidence. Text still checks that a masked element and its label exist. The pin hashes the reference files as stored, unmasked; masking happens on copies at compare time. `undesigned_states` is a closed list of states a static reference cannot show: `hover`, `focus`, `active`, `loading`; any other entry is FAIL. The reference files and the values source are never under the unit's `paths`, and are never a render of the code being scored, except an approved snapshot. An approved snapshot (`"approved_at": "<sha>"` in `reference`) is a screenshot rendered from commit `<sha>`, the one the owner approved. It counts as independent only while `git diff <approved_at> -- <paths>` plus the untracked files under `paths` is non-empty. When that is empty, Render vs reference is PASS as "does not apply: unchanged since approval", with that diff command as evidence; it is never scored as a match. An approved snapshot catches drift from what the owner approved, not from the original design; use a design reference (Paper frame or block) when one still applies. Only the user's accept in the closing `AskUserQuestion` sets `approved_at`, its reference files, or a `mask` entry; the lead never edits them to change a score.

## Paper rules

- **Open the file first.** `list_resources` finds the file id, then `open_file` opens it; `get_basic_info` fails without an open file.
- **App tokens first.** The app's tokens (for example from `src/styles.css`) are set up in the Paper file before the first design or build. `open_file` returns the file's tokens; call `get_tokens` only when they are missing from that answer. Missing or different → `designer` sets them first; a design on other tokens drifts from the app.
- **Read with `get_basic_info`, `get_screenshot` and `get_computed_styles`.** Code from those plus the app's own tokens and components.
- **`get_jsx` output never becomes app code.** It gives fixed px values, Paper-file tokens instead of app tokens, plain divs with no components, and loses layer names.
- **New design only.** Paper is for screens that do not exist yet. An existing screen is a Playwright screenshot of the app; copying 4 screens into Paper cost 26 calls in the trial. Auditing an existing screen with no frame uses `image` mode against its approved screenshot or block thumbnail, never a Paper copy.
- **Budget.** Paper Free allows 100 MCP calls per week, and a new screen costs about 5 plus iterations. Paper does not report what is left, so count the calls per unit and state them in the report.
- **Writes belong to `designer`.** Designs are read-only unless the user explicitly asks to edit the design; then `designer` makes the change with the Paper write tools (`write_html`, `update_styles`, `set_tokens` and the rest). A lead session is denied them. This skill never quietly fixes the design to match the code.

## Run mode

- **Claude Code (preferred):** *build* → delegate each unit to the `designer` subagent via the Task tool with `subagent_type=ai:designer`. Pass: the frame id(s), the target path/route, the project's token file and its two or three most-polished components of the same kind, and from the overlay: the design element → component map, the state recipe, the undesigned states, the copy keys per locale, the interactions, the Paper screenshot plus computed styles when the designer has no Paper MCP (in `image` mode the reference image(s) and the values source), and the audit checklist below, so the first build targets the items it will be scored on. *Score* → one `judge` per unit with `subagent_type=ai:judge`, never the designer or the lead. Pass: the checklist, the pin and the paths in `units.<id>.paths`, the round count, the build screenshots, and the reference files: `paper` mode the Paper screenshots plus the raw `get_computed_styles` output (the judge has no Paper MCP), `image` mode the reference image(s) plus the values source; the click evidence per overlay task; no self-score from the designer. *Prove* → one `verifier` per unit with `subagent_type=ai:verifier`; claim and observation method under **Prove** below. One subagent per unit, in parallel when units are independent (a module's frames usually are). The audit evidence (Paper reads, screenshots) is gathered in the main context; Paper reads need the MCP.
- **Hosts without subagents:** run build, score and prove inline, budgeted per unit (one frame, one render, one verdict before the next). The flows below are the canonical source of truth — `designer`'s prompt mirrors the build rules.

## The five flows

| Flow | Use it when |
|------|-------------|
| **design** | author or iterate a frame, only on explicit request, done by `designer` |
| **audit** | score existing code against its frame; when the sha of the frame's `get_computed_styles` output changed |
| **build** | generate or rebuild a screen from a finished frame |
| **prove** | confirm a built screen is 1:1 with its frame before calling it done |
| **store** | App Store / Play Store screenshot slides, through the `app-store-screenshots` companion |

### design — only when asked

Delegate to `designer` with the Paper frame as the deliverable. It checks the app tokens first, composes from the file's own components, binds tokens instead of literal values, and verifies with `get_screenshot`. Stop and hand back when the user wants to design by hand.

### audit — fidelity per component

For each component the frame maps to, score against the design with this checklist. Each item is yes or no with evidence; an item without evidence fails.

- Code: **text** (every string in the reference exists in the build), **tokens** (colours, type, spacing, radius resolve to the project's tokens), **no hardcoded values** (no hex, px, magic sizes a token already owns), **icons and states** (default / hover / focus / disabled / loading / empty / error present, or missing only when the overlay's undesigned states entry flags it; that entry is the evidence).
- Render: **Render vs reference** (a screenshot of the running build per width next to the reference image of the same unit, the Paper `get_screenshot` or the reference file: same content, order and hierarchy; evidence is both image paths), **Layout** (spacing, alignment and sizes match the reference values, `paper` the frame's `get_computed_styles`, `image` the tokens file or block source, within the overlay's `tolerance`, default 0: the measured value equals the reference value or resolves to the same token; evidence is the measured value next to the reference value), **Breakpoints** (a render at every width in the overlay's `breakpoints`, plus any extra width the frame defines; one screenshot per width), **Theme** (every theme in the overlay's `themes`; one screenshot per theme), **No overflow** (no overflow, clipping or text truncation the reference does not show; a screenshot).
- UX: **Clicks** (for each overlay `tasks` entry whose `unit` names this unit, starting at the task's `route`: the lead passes a click log with one line per pointer click, `<n>. click <selector> → <url>`; only those lines count; PASS when the count ≤ `max`). No task names this unit: Clicks does not apply; evidence: `jq '.tasks[] | select(.unit=="<id>")' .agents/design-to-code.overlay.json` is empty. Clicks counts the mouse-only path: the log is recorded without keyboard navigation (no Tab or Enter to move or submit), typing into a field is free, and every pointer click counts.

A render item without a screenshot fails. Score = passed items / total items × 100, per component, not averaged: an average hides the outlier, so the lowest component is the deliverable's score.

Audit the design too, for what the code will need: every interactive element has its states drawn; every overlay the code opens (dialog, sheet, confirm, drawer — grep the code for them) has a frame; contrast and touch targets hold. A missing secondary screen is a blocker, not a note.

Bar: every component ≥ 100 unless the overlay's `bar` sets another threshold. A `judge` spawn scores it, pinned to the reference (`paper`: the frame id and the sha of its `get_computed_styles` output; `image`: the image sha `shasum <files in listed order> | shasum` (run from the repo root, paths exactly as in `reference.files`) and the sha of the values source), the overlay pin (`jq -S 'del(.units[].pin)' .agents/design-to-code.overlay.json | shasum`) and the code pin (`git rev-parse HEAD` plus `{ git diff HEAD -- <paths>; git ls-files -o --exclude-standard -z -- <paths> | xargs -0 shasum; } | shasum`) over the paths in `units.<id>.paths`. Below the bar → send the judge's fix list to `designer`, fix the code, re-score. At most two fix rounds: build → judge → fix → judge → fix → judge. The lead counts rounds and passes the count to the judge. Still below the bar after fix round 2 of 2 → stop and hand the user the score and the open items. Every run ends with an `AskUserQuestion` to the user, also when green: the score, the evidence summary, the open items, and accept / one more round / reject. The score goes up only by repairing code: never by loosening the threshold, widening exceptions, or editing the design. A suspected measurement error is reported with evidence, not silently overruled; a *recurring* one becomes code in the project's check script, not a note in this skill.

Who fixes what: drift and a below-bar score go back to `designer`; a gap (a component or section with no frame or no map entry) and a contrast failure that needs a token change you propose — those are the user's decisions. Never write a design string from memory: read the node, then record it.

Copy has its own traps, because a text gate compares literal substrings: a copy change lands in the frame *and* in the code in the same pass, identical string. Frame first, but never frame only. Sample or placeholder text recorded in the project's map is a literal copy of the canvas: rename the placeholder, update the map, or the section's score drops. For a copy pass the review surface is a `get_screenshot` of each changed artboard plus a change list, not a sibling frame per line.

### build — delegate to `designer`

Per unit: source order is the project's own tokens and best existing components first, the project's design skill second, an installed design-intelligence skill (what to choose) or web-platform-guidance skill (how to build it with the platform) third for gaps only. Tokens never literals; reuse before creating; both themes; responsive; accessibility; interaction states including empty and error. `designer` returns a Design sources / Changed / States covered / Verified report — read it, then prove.

Three rules two repos each learned the hard way:

- **Spec table before the first line of code.** Extract the frame's exact values (sizes, tokens, copy, per element) from `get_computed_styles` into a table, mapped to the app's tokens, and build from it; the same rows become the assertions in prove. The screenshot shows the layout; it never supplies a value. Building from the screenshot is how a 22/800 heading ships as 17/600.
- **Frame proposes, contract disposes.** Where the screen maps a backend resource, the frame decides which fields and in what order; the API contract (OpenAPI, SDK types) decides names and types. A field the frame shows and the contract lacks is a mock-only field plus an issue for the backend — never an invented column. Screens that map no resource are exempt.
- **Rebuild means clean slate.** Replacing an existing screen: remove the old implementation first (keep routing, wiring, mocks), then build from the frame. Layering new on old carries every old assumption into the "1:1" result.

### prove — delegate to `verifier`

Claim: **"`<component or route>` matches design frame `<id>`."** The main thread produces both pieces of evidence — `verifier` has no MCP and no dev server — and passes them in: the frame's Paper screenshot (`get_screenshot`, taken by the main thread or `designer`) and the render of the built code, obtained as follows:

- **Web:** render the built route (dev server, story, or the project's HTML build) and screenshot at the frame's width. `verifier` compares block by block — order, spacing, type, colours, icons, grouping, copy, empty state.
- **Web — two viewports.** Look at the render at true size on a desktop and a phone viewport; a text/token script cannot see a layout that broke. This is a procedural step on purpose: font rendering differs per machine, so a snapshot diff goes structurally red and gets ignored.
- **Flutter / mobile: live on device at two densities.** Screenshot the screen with real data, in the state the overlay's recipe names, on the emulator and the user's phone class (a second density on the same emulator counts; two identical emulators prove nothing). A sizing bug only shows as a difference between devices. `verifier` compares each against the Paper screenshot. Goldens green is part of this step, never a substitute for it.

**Not drift** — name it in the report, do not fix it: sample data in the frame versus real data; a state the frame does not depict (disabled at a bound, keyboard open); platform copy a single-OS frame cannot carry — check the other platform's copy explicitly, that is where slips hide. Token values follow code where a token-sync check exists; layout, copy and states follow the design.

**Shape of a multi-screen prove.** Read-only sweep agents (one per device, both densities) produce claims → `verifier` tests each claim before anyone edits (in a 30-claim run, two named the wrong field) → a fix batch that never commits → one committer lands one commit per finding. Never edit on an unverified sweep claim.

**What a proof can and cannot say.** A golden or self-baseline compares the app with *itself*: it locks regressions and can never show app ≠ design — only a compare against the Paper screenshot can. Colour is the leg that slips: assert it explicitly, and pick a component's variant by the node's colour token, never by its name or role. A test entry (a query param, a flag, a fixture switch) may swap data and state, never styling — a style that only exists behind the test entry proves the test URL, not production.

A judge PASS with a verifier REFUTED is not done: done needs CONFIRMED, so the verifier wins. Verdict CONFIRMED means done; REFUTED means the counter-evidence is the next fix; UNTESTABLE means say what could not be observed — never upgrade it to a pass.

### store — route to the companion

Mobile is not designed in Paper yet, so store slides come from the `app-store-screenshots` companion (offered by `/ai:recommend-tools` for mobile apps). Feed it 3x simulator captures. List the sizes each target store requires before building: the stores reject a size that is one pixel off. This flow moves back here once mobile screens are designed in Paper.

## Modes

- **Single.** One frame: (design →) build → prove → **user OK** → next. The OK is the load-bearing half of the cadence: it is what stops building ahead of the phase.
- **Batch.** A module = one Paper page's artboards. Enumerate them with `get_basic_info`, then per frame build → prove, in parallel where independent. Finish with a per-screen table `frame · route · audit · live ×2 · drift found → fixed · parity · in code (path)` **in the chat**, not only in a doc, and list every frame you did **not** generate and why — skip nothing silently. Never put a screen at 100 with an open finding: fix, then report.

## Definition of done

Judge score at the bar for every component; prove CONFIRMED per unit; zero unresolved drift; user OK given through the closing `AskUserQuestion`. Then `designer` marks it on the canvas with one `rename_nodes` call that puts a ✅ and the source path in the artboard's name, for example `✅ Relaties lijst · src/routes/relaties.tsx`. In batch mode one `designer` spawn marks the whole module at the end. The canvas is what the next person opens; a status table drifts. Done is derived, not declared: the code names its frame where a grep finds it (a `data-design-id`, a comment, a map entry), the check that passed carries the pin from **Bar**, stored in the overlay's `units.<id>.pin`, and an exemption carries a reason, an owner and an expiry (≤ 30 days). A permanent exemption is a lie with a config key. Never claim "1:1" or "pixel-perfect" from a glance; cite the verdict and the render it was based on. The tie-break and cadence this skill assumes live in the [design-leads rule](../../../standards/rules/design-leads.mini.md).
