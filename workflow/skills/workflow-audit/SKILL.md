---
name: workflow-audit
description: Audit the ai-kit idea-to-release workflow with three read-only explore agents and write a dated report with a delta against the previous run; use when /ai:checkpoint or /ai:next says the last audit is over 30 days old, after a release that changed the chain, or when the user asks how the workflow is doing.
---

# Workflow audit

Measure the kit's own workflow, compare with the previous run, and propose slices only for what moved. Runs in the ai-kit repo.

## 1. Find the previous report

```bash
ls docs/audits/workflow-audit-*.md 2>/dev/null | sort | tail -1
```

Its date is `<since>`. Its Key figures, Patterns, Per repo and Test coverage gaps tables are the comparison base, and its Per repo table (names and paths) is the repo list. No report yet: `<since>` is 30 days ago and the Delta section says "first run".

## 2. Spawn three explore agents in parallel

One message, three Task calls, each `subagent_type=ai:explore` (Sonnet-pinned, read-only). Each prompt starts with these rules, then the full text of its brief, then its inputs:

> Read-only. Return at most 300 lines. Every claim cites `path:line` or the command that produced it. Never read session transcripts (`*.jsonl`). Every `gh` call passes `--repo <owner>/<name>`. End with "Files inspected" and "Confidence".

| Agent | Brief | Inputs |
| ----- | ----- | ------ |
| chain | [brief-chain.md](brief-chain.md) | kit root |
| delivery | [brief-delivery.md](brief-delivery.md) | kit root |
| evidence | [brief-evidence.md](brief-evidence.md) | kit root, `<since>`, repo list from the previous report |

Wait for all three. Do not start the next step on a partial set. An agent that returns over budget or without `file:line` citations goes back once with "cut to 300 lines, cite every claim".

## 3. Merge

- Drop a finding with no citation. Keep the one with the newest source when two agents disagree, and note the conflict.
- A pattern needs two or more pieces of evidence from different sources; one piece goes under the section it came from, not under Patterns.
- Check each claim of the previous report against the new findings: still there, gone, or worse.

## 4. Delta rule

Each key figure is in one of five states against the previous report: **new**, **worse**, **better**, **stable**, or **not measured** (no value this run; never guess one). Stable when |Δ| ≤ max(1, 10% of the previous value); for percentages, |Δ| ≤ 5 percentage points. Stable figures get the word "stable" and no slice. A new or worse item gets a slice. A better item goes under Resolved and names the commit or release that resolved it. A not-measured figure says why.

## 5. Write the report

Path: `docs/audits/workflow-audit-<YYYY-MM-DD>.md`. Sections come from: Key figures and Per repo from evidence; Claim versus reality, Models and Test coverage gaps from delivery; Chain breaks from chain; Patterns, Delta and Recommended slices from the merge. Sections in this order, none empty (write "none found" when true):

```markdown
# Workflow audit <date> (kit v<VERSION>)

Window: <since> to <date>. Busiest repo: the repo with the most commits in the window.

## Key figures
| Measure | Value | Previous | Source |
(rows: lead-inline sessions; owner-found defects per week in the busiest repo;
review gate in effect per repo (yes/no: marker >= 2.17.0 and
`jq -r '.branches.review_gate_hook // "wired"' .ai-kit-setup` is `wired`);
gate skips logged per repo (main git-dir only); fix ratio per repo; open re-measurements;
open kit issues. Source quotes the exact command or file:line)

## Per repo
| Repo | Path | Marker version | Lifecycle | Fix ratio |

## Claim versus reality
## Chain breaks
## Models
## Test coverage gaps
## Patterns
(numbered; each with two or more evidence citations)
## Delta since previous audit
### New
### Resolved
### Worse
### Stable
### Not measured
## Recommended slices
(one line each: title, why, evidence; max 7, ranked)
```

Role check before writing: if this session's claim says `role=lead`, lead-guard denies repo writes. Hand the merged content to a general-purpose agent with model sonnet and the brief "write this file verbatim at <path>, touch nothing else". Otherwise write it yourself.

## 6. Hand off

Print the report path, the key-figures table, and the slice list. Ask which slices become issues; route accepted ones to `/ai:to-issues`. Never open issues unasked and never commit the report unasked.
