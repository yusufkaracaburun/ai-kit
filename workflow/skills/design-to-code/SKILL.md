---
name: design-to-code
description: Turn a design file into code and prove the code still matches it — design → audit → build → prove against a `.pen` (Pencil) or other MCP-readable design source. Use when the user says "design naar code", "bouw dit scherm uit het design", "klopt de code met het design", "design sync", "parity check", after a `.pen` change, or via /ai:design-to-code. Not for choosing a visual direction (that is design-direction).
---

# Design to code

The design file is the source of truth. Code follows it; drift is a finding, never a taste difference. Four flows — design, audit, build, prove — run one screen at a time or a whole module in batch.

Stack-agnostic: this skill carries the procedure, the bar, and the delegation shape. Project specifics — token names, route language, frame ids, the project's own gates — are an overlay the project keeps in its own `.agents/skills/` (or `.claude/skills/`); they do not belong here.

## Step 0 — precondition and ownership

1. **Design source present?** A `.pen` file plus the Pencil MCP (`pencil` / `pencil-cursor`) reachable, or another design-file MCP the host exposes. Nothing → stop. Point at [design-direction](../design-direction/SKILL.md) when the question is *which* direction, or do the UI work inline; do not invent a design and call it parity.
2. **Repo already owns this job?** `ls .claude/skills/ .agents/skills/ 2>/dev/null` — a project-local design/pencil skill outranks this one. Load it, follow it, say so in the report. Only continue below when none exists.

### The project overlay

The overlay is a pointer file, not a second copy of this skill. It carries what only the project knows; a build that has to ask for any of these mid-unit was handed an incomplete overlay:

- **Frame → route map** and **master → component map** (which design master is which widget/component). A frame that uses a master with no component yet is a component task first.
- **State recipe per screen** — the exact app state the frame shows, as data: which account, which record, which time; plus how to reach it (a fixture, an E2E helper, a mock endpoint). Reaching the state is the cost of the live compare, not the screenshot.
- **All states**, not the happy one: loading, empty, error, and which of those the frame does not depict.
- **Copy per locale** — a frame usually carries one language; the others must not be invented on the code side each time.
- **Interactions** — tap targets and where they go, sheet rows, gestures.
- **Sweep parameters** — master naming prefix, raw-frame name pattern, and the devices/viewports the live step uses (see [pencil-sweep.md](pencil-sweep.md)).
- **Pointers** to the project's gate doc and ADRs; the overlay never restates them.

## Hard rules for `.pen`

- **Never `Read` or `Grep` a `.pen` file.** They are encrypted; you will hallucinate a design from the bytes. Pencil MCP tools only. The one exception is a project that keeps a plain-JSON `.pen` in the repo and reads it with its own scripts — `head -c 200` tells you which kind you have.
- **`get_app_state` first.** No other Pencil tool works without the current schema in context; it also tells you which file is active.
- **Designs are read-only** unless the user explicitly asks to edit the design. This skill converts designs into code; it does not quietly fix the design to match the code.

## Run mode

- **Claude Code (preferred):** *build* → delegate each unit to the `designer` subagent via the Task tool with `subagent_type=designer`. Pass: the frame id(s), the target path/route, the project's token file and its two or three most-polished components of the same kind, and from the overlay: the master → component map, the state recipe, the undesigned states, the copy keys per locale, the interactions. *Prove* → one `verifier` per unit with `subagent_type=verifier`; claim and observation method under **Prove** below. One subagent per unit, in parallel when units are independent (a module's frames usually are). Audit stays in the main context — it needs the MCP.
- **Hosts without subagents:** run build and prove inline, budgeted per unit (one frame, one render, one verdict before the next). The flows below are the canonical source of truth — `designer`'s prompt mirrors the build rules.

## The four flows

| Flow | Use it when |
|------|-------------|
| **design** | author or iterate a frame — only on explicit request |
| **audit** | score existing code against its frame; after any `.pen` change |
| **build** | generate or rebuild a screen from a finished frame |
| **prove** | confirm a built screen is 1:1 with its frame before calling it done |

### design — only when asked

Compose from the design's own library (reuse components as instances, never redraw a primitive), bind tokens instead of literal values, check layout problems per section before moving on, screenshot to verify. Stop and hand back when the user wants to design by hand.

### audit — fidelity per component

For each component the frame maps to, score against the design: **text** (every string in the design exists in the build), **tokens** (colours, type, spacing, radius resolve to the project's tokens), **no hardcoded values** (no hex, px, magic sizes a token already owns), **icons and states** (default / hover / focus / disabled / loading / empty / error present or explicitly flagged). Per component, not averaged — an average hides the outlier. A missing text is never a taste difference.

For a `.pen` frame, start with a *structural sweep* via the MCP — scripts and parameters in [pencil-sweep.md](pencil-sweep.md): frames with ≥2 children and no explicit layout, real layout problems, masters left as loose copies, the same raw structure repeated on two or more screens (promote it first). Those are design defects to raise before scoring code against them. A plain-JSON `.pen` runs the same sweep as a script, as an audit, never as a commit gate.

Beyond structure, audit the design for what the code will need: every interactive element has its states drawn; every overlay the code opens (dialog, sheet, confirm, drawer — grep the code for them) has a frame; contrast and touch targets hold. A missing secondary screen is a blocker, not a note.

Bar: every component ≥ 90 unless the project's overlay sets another threshold. Below the bar → fix the code, re-score. The score goes up only by repairing code: never by loosening the threshold, widening exceptions, or editing the design. A suspected measurement error is reported with evidence, not silently overruled; a *recurring* one becomes code in the project's check script, not a note in this skill.

Who fixes what: drift and a below-bar score you fix yourself; a gap (a component or section with no frame or no map entry) and a contrast failure that needs a token change you propose — those are the user's decisions. Never write a design string from memory: read the node, then record it.

Copy has its own traps, because a text gate compares literal substrings: a copy change lands in the frame *and* in the code in the same pass, identical string — frame first, but never frame only. Sample or placeholder text recorded in the project's map is a literal copy of the canvas: rename the placeholder, update the map, or the section's score drops. Text inside a master changes the master's hash, so every instance's check re-runs and an accept-with-reason is part of any copy pass, not an afterthought. For a copy pass the review surface is the design file's diff plus a change list — not a sibling frame per line.

### build — delegate to `designer`

Per unit: source order is the project's own tokens and best existing components first, the project's design skill second, an installed design-intelligence skill (what to choose) or web-platform-guidance skill (how to build it with the platform) third for gaps only. Tokens never literals; reuse before creating; both themes; responsive; accessibility; interaction states including empty and error. `designer` returns a Design sources / Changed / States covered / Verified report — read it, then prove.

Three rules two repos each learned the hard way:

- **Spec table before the first line of code.** Extract the frame's exact values — sizes, tokens, copy, per instance — into a table and build from it; the same rows become the assertions in prove. A text dump is for copy; a screenshot is for nothing. Building from either is how a 22/800 heading ships as 17/600.
- **Frame proposes, contract disposes.** Where the screen maps a backend resource, the frame decides which fields and in what order; the API contract (OpenAPI, SDK types) decides names and types. A field the frame shows and the contract lacks is a mock-only field plus an issue for the backend — never an invented column. Screens that map no resource are exempt.
- **Rebuild means clean slate.** Replacing an existing screen: remove the old implementation first (keep routing, wiring, mocks), then build from the frame. Layering new on old carries every old assumption into the "1:1" result.

### prove — delegate to `verifier`

Claim: **"`<component or route>` matches design frame `<id>`."** The main thread produces both pieces of evidence — `verifier` has no MCP and no dev server — and passes them in: the frame export (PNG or `html-css` via the MCP) and the render of the built code, obtained as follows:

- **Web:** render the built route (dev server, story, or the project's HTML build) and screenshot at the frame's width. `verifier` compares block by block — order, spacing, type, colours, icons, grouping, copy, empty state.
- **Web — two viewports.** Look at the render at true size on a desktop and a phone viewport; a text/token script cannot see a layout that broke. This is a procedural step on purpose: font rendering differs per machine, so a snapshot diff goes structurally red and gets ignored.
- **Flutter / mobile — two renders.** (1) *Full-scale render* — export the scope to `html-css`, serve it locally, capture at true pixel size (a thumbnail hides a collapsed divider). Only worth it right after `.pen` edits: it tests the design against itself. (2) *Live on device at two densities* — screenshot the screen with real data, in the state the overlay's recipe names, on the emulator and the user's phone class (a second density on the same emulator counts; two identical emulators prove nothing). A sizing bug only shows as a difference between devices. `verifier` compares each against the frame export (`png` at 1.5×, see [pencil-sweep.md](pencil-sweep.md)). Goldens green is part of this step, never a substitute for it.

**Not drift** — name it in the report, do not fix it: sample data in the frame versus real data; a state the frame does not depict (disabled at a bound, keyboard open); platform copy a single-OS frame cannot carry — check the other platform's copy explicitly, that is where slips hide. Token values follow code where a token-sync check exists; layout, copy and states follow the design.

**Shape of a multi-screen prove.** Read-only sweep agents (one per device, both densities) produce claims → `verifier` tests each claim before anyone edits (in a 30-claim run, two named the wrong field) → a fix batch that never commits → one committer lands one commit per finding. Never edit on an unverified sweep claim.

**What a proof can and cannot say.** A golden or self-baseline compares the app with *itself*: it locks regressions and can never show app ≠ design — only a compare against the design export can. Colour is the leg that slips: assert it explicitly, and pick a component's variant by the node's colour token, never by its name or role. A test entry (a query param, a flag, a fixture switch) may swap data and state, never styling — a style that only exists behind the test entry proves the test URL, not production.

Verdict CONFIRMED means done; REFUTED means the counter-evidence is the next fix; UNTESTABLE means say what could not be observed — never upgrade it to a pass.

## Modes

- **Single.** One frame: (design →) build → prove → **user OK** → next. The OK is the load-bearing half of the cadence: it is what stops building ahead of the phase.
- **Batch.** A module = one design file's top-level frames. Enumerate them via the MCP (the app-state list truncates), then per frame build → prove, in parallel where independent. Finish with a per-screen table `frame · route · sweep · live ×2 · drift found → fixed · parity · in code (path)` **in the chat**, not only in a doc, and list every frame you did **not** generate and why — skip nothing silently. Never put a screen at 100 with an open finding: fix, then report.

## Definition of done

Audit score at the bar for every component; prove CONFIRMED per unit; zero unresolved drift; user OK given. Then mark it on the canvas: a ✅ in the frame's label plus a node holding the source path — the canvas is what the next person opens, a status table drifts. Done is derived, not declared: the code names its frame where a grep finds it (a `data-design-id`, a comment, a map entry), the check that passed is pinned to the hash of the frame it ran against, and an exemption carries a reason, an owner and an expiry (≤ 30 days) — a permanent exemption is a lie with a config key. Never claim "1:1" or "pixel-perfect" from a glance — cite the verdict and the render it was based on. The tie-break and cadence this skill assumes live in the [design-leads rule](../../../standards/rules/design-leads.mini.md).

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" design-to-code start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" design-to-code done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
