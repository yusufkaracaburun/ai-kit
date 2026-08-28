---
name: harvest
description: Promote a pattern a shipped app already solved well into an ai-kit rule, so the next app starts with it instead of reinventing it. Use when the user says "harvest this", "turn this into a rule", "we solved this well, keep it", "why did we solve this twice", "/ai:harvest", or after finishing work whose approach should outlive the repo it was written in.
---

# Harvest

Turn one pattern a real repo already solved into a canonical rule under `standards/rules/`. This is the inverse of every other ai-kit skill: they push the kit into an app, this pulls an app's earned knowledge back into the kit. Without it the flow is one-directional and every new app re-solves what the last one figured out.

Harvesting is not authoring. The material must already exist, already ship, and already be guarded by something. If you find yourself inventing the content, you are writing a rule from theory — stop and say so.

## Not this skill

- **An ai-kit skill produced a bad output** — that is [`contribute-eval`](../contribute-eval/SKILL.md). Harvest promotes what an *app* got right; contribute-eval captures what the *kit* got wrong.
- **A tool, library or repo someone linked** — that is [`should-i-use`](../should-i-use/SKILL.md), and community rules go through [`recommend-rules`](../recommend-rules/SKILL.md) under the two-source promotion quorum. External material has a different evidence bar than your own shipped code.
- **A fix that only makes sense in this repo** — a workaround for one vendor's API, a migration for one schema. Real, valuable, not a rule.
- **Something you just wrote and have not shipped** — come back when it has survived contact with production.

If the input matches one of the above, route and stop.

## The bar

A candidate is harvestable only when all three hold. State each explicitly, with evidence from the repo:

1. **Shipped** — it is on the main branch and running, not a branch or a plan.
2. **Guarded** — a test, a CI check, or a deploy check fails when it breaks. If nothing guards it, the pattern is a habit, not a practice, and habits do not survive being written down.
3. **Would have applied elsewhere** — name a second repo the user owns where this would have fired. Not a hypothetical repo, a real one. If you cannot name it, the pattern is repo-local.

This bar deliberately differs from `standards/promotion-quorum.md`. That governs *external* material, where two independent sources substitute for trust. Here the evidence is your own running code, which is stronger than two blog posts — but only if it actually runs and is actually guarded.

## Process

### 1. Locate the material

Default source is the current repo. Ask which pattern if the user has not named one; otherwise look where earned knowledge accumulates: a `Support/` or `lib/` layer with a coherent job, a test file that asserts a cross-cutting concern rather than a feature, a Makefile or CI step that checks something non-obvious, a comment explaining why an obvious approach was rejected.

Read the implementation *and* its guard before proposing anything.

### 2. Apply the bar

Walk the three criteria out loud with paths and counts. Reject loudly rather than stretching — a harvest that fails criterion 3 is the common case, and saying so is the skill working.

### 3. Check what already covers it

Run `bin/emit-rules.sh --list` and grep `standards/rules/` for the concepts, not the words. The trap is partial coverage: a rule scoped to one stack often already carries the knowledge for that stack only. That is not "already covered" — it is the evidence that the knowledge failed to travel.

When a stack-scoped rule half-covers it, prefer generalising the existing rule over adding a second one that overlaps.

### 4. Make the four judgment calls

This is the part a script cannot do. Answer each in the proposal:

- **What generalises.** Strip the stack and keep the mechanism. Test: can you state the rule without naming the framework? If yes it is a candidate for universal content; if no, it is stack-scoped and belongs in `applies_to`.
- **Which `universal` flag.** `universal: true` emits into *every* repo by default — `bin/emit-rules.sh` selects on that flag alone. Ask whether a repo without this concern still benefits. Usually no. Default to `universal: false` and let `recommend-rules` surface it; always-on is a claim about every future project.
- **What the sharp core is.** A harvested rule that reads as a checklist wasted the harvest. Find the trap: the thing that fails *silently*, where the obvious guard passes anyway. The checklist items are context; the trap is the reason the rule exists.
- **Where the guard belongs.** Some patterns are guarded by a test, some only by a deploy or CI check because the failure needs a running system. Say which, and do not propose a test that cannot run — verify by measuring, not by assuming it will work.

### 5. Write the rule

If step 3 landed on a merge, this is a few bullets added to the host rule's existing section — same discipline, no frontmatter — and you skip to step 6. Otherwise create `standards/rules/<name>.mini.md`, matching the frontmatter of an existing sibling exactly:

```yaml
---
name: <kebab-name>
description: <one line, the mechanism not the topic>
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---
```

Body: a short opening that names the failure mode, `##` sections of terse bullets, a `## Hard rules` section, and `## See also` links to the rules it sits next to. Cite the mechanism, never the source repo — a rule that reads like a postmortem of one app will not be applied to another.

### 6. Land it

Which path depends on step 3: a merge into an existing rule is the cheaper landing and the one to prefer.

**A new rule, inside the ai-kit clone:**

```bash
bash bin/emit-rules.sh --list | grep <name>          # discoverable
bash bin/emit-rules.sh <tmpdir> --rules <name>       # emits end to end
bash bin/count-primitives.sh --check                 # rule total moved; fix every surface it names
bash tests/bin/run-all.sh                            # full suite, including the --list count assertion
bash bin/sync-plugin-standards.sh                    # mirror into workflow/standards/
```

The count guard will fire — that is expected. It names each file carrying a hardcoded total; update all of them plus the `--list` assertion in `tests/bin/cases/bootstrap-emit.sh`.

**A merge into an existing rule:**

```bash
bash tests/bin/run-all.sh                            # full suite
bash bin/sync-plugin-standards.sh                    # mirror into workflow/standards/
```

The rule total did not move, so the count guard stays silent and the `--list` assertion is untouched — do not go looking for either. What still applies: the merged bullets carry the mechanism and the silent failure, not a summary of the source repo, and the host rule's scope must actually reach the repos that supplied the evidence. If it does not, the merge is wrong and it wants its own rule.

**From another repo:** open a PR against `yusufkaracaburun/ai-kit` on branch `harvest/<name>` adding the rule file, with a body that states the three bar criteria and the evidence for each. Show the user the full rule and PR body before any `gh` write call.

## Hard rules

- **No harvest without a guard.** Criterion 2 is not negotiable. Unguarded patterns rot between the repo and the next reader.
- **Name the second repo.** Criterion 3 in the abstract is how kits accumulate rules nobody asked for.
- **Generalise the wording, keep the mechanism.** Strip repo names, class names and domain nouns; keep the failure it prevents.
- **Prefer merging into an existing rule** over adding an overlapping one. Two rules covering one concern is worse than none.
- **Never invent the missing half.** If the pattern is half-built in the source repo, harvest the half that ships and say what was left out.
- **One pattern per harvest.** Two patterns are two rules and two reviews.

## Why this exists

Every other path in this kit runs kit → app. `contribute-eval` is the only backflow and it captures only the kit's own failures, never an app's wins. So an app can solve something better than the kit knows how, and the next app still starts from zero.

That is not hypothetical. `public-surface.mini.md` was harvested from an app that had independently built a server-side metadata layer, a route-derived sitemap and a CI-gated regression suite, none of which any rule covered — while a sibling repo solved the same problem separately, and a stack-scoped rule already carried half the answer without ever crossing the stack boundary. Two apps, one problem, three partial solutions, zero transfer. This skill exists so the second app pays for the first one's learning instead of repeating it.

## See also

- [`contribute-eval`](../contribute-eval/SKILL.md) — the other half of the loop: the kit's failures, not the app's wins.
- [`recommend-rules`](../recommend-rules/SKILL.md) — where harvested rules reach the next project.
- [`should-i-use`](../should-i-use/SKILL.md) — the external-material path, with a different evidence bar.
- `standards/promotion-quorum.md` — the two-source bar this skill deliberately does not use.
- `bin/emit-rules.sh` — selection is on the `universal` flag alone; that is why step 4 treats it as a decision.
