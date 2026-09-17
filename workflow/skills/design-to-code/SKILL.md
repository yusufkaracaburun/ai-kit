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

## Hard rules for `.pen`

- **Never `Read` or `Grep` a `.pen` file.** They are encrypted; you will hallucinate a design from the bytes. Pencil MCP tools only.
- **`get_app_state` first.** No other Pencil tool works without the current schema in context; it also tells you which file is active.
- **Designs are read-only** unless the user explicitly asks to edit the design. This skill converts designs into code; it does not quietly fix the design to match the code.

## Run mode

- **Claude Code (preferred):** *build* → delegate each unit to the `designer` subagent via the Task tool with `subagent_type=designer`. Pass: the frame id(s), the target path/route, the project's token file and its two or three most-polished components of the same kind. *Prove* → one `verifier` per unit with `subagent_type=verifier`; claim and observation method under **Prove** below. One subagent per unit, in parallel when units are independent (a module's frames usually are). Audit stays in the main context — it needs the MCP.
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

For each component the frame maps to, score against the design: **text** (every string in the design exists in the build), **tokens** (colours, type, spacing, radius resolve to the project's tokens), **no hardcoded values** (no hex, px, magic sizes a token already owns), **icons and states** (default / hover / focus / disabled / loading / empty / error present or explicitly flagged). Per component, not averaged — an average hides the outlier. A missing text is never a taste difference. For a `.pen` frame, start with a *structural sweep* via the MCP: frames with ≥2 children and no explicit layout, real layout problems, masters left as loose copies — those are design defects to raise before scoring code against them.

Bar: every component ≥ 90 unless the project's overlay sets another threshold. Below the bar → fix the code, re-score. The score goes up only by repairing code: never by loosening the threshold, widening exceptions, or editing the design. A suspected measurement error is reported with evidence, not silently overruled.

### build — delegate to `designer`

Per unit: source order is the project's own tokens and best existing components first, the project's design skill second, an installed design-intelligence skill third for gaps only. Tokens never literals; reuse before creating; both themes; responsive; accessibility; interaction states including empty and error. `designer` returns a Design sources / Changed / States covered / Verified report — read it, then prove.

### prove — delegate to `verifier`

Claim: **"`<component or route>` matches design frame `<id>`."** The main thread produces both pieces of evidence — `verifier` has no MCP and no dev server — and passes them in: the frame export (PNG or `html-css` via the MCP) and the render of the built code, obtained as follows:

- **Web:** render the built route (dev server, story, or the project's HTML build) and screenshot at the frame's width. `verifier` compares block by block — order, spacing, type, colours, icons, grouping, copy, empty state.
- **Flutter / mobile — two renders.** (1) *Full-scale render* — export the scope to `html-css`, serve it locally, capture at true pixel size (a thumbnail hides a collapsed divider). (2) *Live on device at two densities* — screenshot the screen with real data on the emulator and the user's phone class; a sizing bug only shows as a difference between devices. `verifier` compares each against the frame export.

Verdict CONFIRMED means done; REFUTED means the counter-evidence is the next fix; UNTESTABLE means say what could not be observed — never upgrade it to a pass.

## Modes

- **Single.** One frame: (design →) build → prove.
- **Batch.** A module = one design file's top-level frames. Enumerate them via the MCP (the app-state list truncates), then per frame build → prove, in parallel where independent. Finish with a per-screen table `frame · route · build · parity` and list every frame you did **not** generate and why — skip nothing silently.

## Definition of done

Audit score at the bar for every component; prove CONFIRMED per unit; zero unresolved drift. Never claim "1:1" or "pixel-perfect" from a glance — cite the verdict and the render it was based on.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" design-to-code start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" design-to-code done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.
