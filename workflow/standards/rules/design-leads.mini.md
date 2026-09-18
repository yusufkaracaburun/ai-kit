---
name: design-leads
description: Design file is the source and code follows it — a fixed tie-break, a not-drift list, one screen at a time with a user OK, and a done-marker on the canvas so "matches the design" is a verdict, not a glance
applies_to:
  frameworks: [pencil]
  languages: []
  architectures: []
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Design leads

A design file and a codebase drift the moment two people can each call the
other one wrong. Without a fixed tie-break every difference is a taste
argument, "done" gets declared from a thumbnail, and the file nobody edits
becomes the one nobody trusts. This rule fixes the direction and the bar.

## Tie-break

- The design file is the source; code follows it. A difference between a
  built screen and its frame is a **drift**, never a taste difference.
- Drift is fixed design-first: change the frame (through the gate), then the
  code. Never edit the frame to match code that was already written.
- Token *values* may flow the other way when a token-sync check exists —
  layout, copy and states never do.

## Not drift

Name these in the report instead of "fixing" them:

- Sample data in the frame (names, dates, counts) versus real data on screen.
- A state the frame does not depict (disabled at a bound, loading, keyboard
  open). Say the state is undesigned; do not invent a design for it.
- Platform copy the frame cannot carry (a frame drawn for one OS, shipped on
  two). Check the other platform's copy explicitly; it is where slips hide.

## Cadence

- One screen → self-review → **user OK** → next. The OK is the load-bearing
  half: it is what stops building ahead of the phase.
- Never report a screen at 100 with an open finding. Fix, then report.
- Report in the chat, as a table, not only in a doc.

## Done-marker on the canvas

- When a screen is in code **and** the user said OK, mark the frame on the
  canvas itself: a ✅ in the label plus a node holding the source path. A
  status table in a doc drifts; the canvas is what the next person opens.
- Keep the progress doc short: archive closed phases to a sibling file. A
  thousand-line progress doc is read by every session and by nobody.
- Done is derived from artefacts, not declared: the code names its frame where
  a grep can find it, the check that passed is pinned to the hash of the frame
  it ran against, and an exemption has a reason, an owner and an expiry.
  A permanent exemption is a lie with a config key.

## Editing the design

- Reuse before redraw: an element that has a master is an instance, never a
  loose copy; a structure repeated on two screens gets a master first.
- A component's debut on a real screen is a test, not a wiring step. If it
  does not fit its neighbours, choose out loud: change the master, promote a
  named variant, or fix the layout around it — never an instance-only
  override.
- A visual "could be better" proposal goes on the canvas as a sibling frame
  next to the current one so the user compares at true size; the loser is
  deleted. A copy pass is reviewed as the design file's diff plus a change
  list — a sibling per line drowns the canvas.
- After changing a token, read it back and confirm the exact name changed.
  A typo creates an orphan token beside the real one and nothing rebinds.

## Hard rules

- Design is the source; code follows. Drift is fixed frame-first.
- No 100 with an open finding; no "matches the design" without a render
  looked at.
- One screen at a time, with a user OK before the next.
- Done means marked on the canvas and derived from a pinned check, not
  declared in a table.

## See also

- [`design-tokens.mini.md`](./design-tokens.mini.md) — the token contract.
- [`ui-states.mini.md`](./ui-states.mini.md) — the states a frame must show.
- `workflow/skills/design-to-code/SKILL.md` — the gate this rule assumes.
