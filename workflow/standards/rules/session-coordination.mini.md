---
name: session-coordination
description: Peer Claude Code sessions on this machine — claims registry, one lead per repo, four messaging triggers, decision relay
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# Session coordination

Other Claude Code sessions may be live on this machine (`ListAgents`). The peer-sessions hook injects this only when peers exist — solo, there is nothing to coordinate.

- Register a claim at start and refresh it when your scope changes: `ai-kit-claim.sh set role=<lead|build|design|e2e|review> owns=<paths, .pen frames, devices> provides=<api version, release> depends_on=<repos, resources>`.
- One lead per repo, named by the user. The lead owns push/merge order; non-leads commit locally and report to the lead. No lead named → the first session on the repo is lead and says so in its claim.
- The lead dispatches, it never executes. Code, tests, builds, e2e, commits, design edits (`.pen`), browser and store-console flows, CLI release ops (`asc`, `gh`, `eas`) and log redaction all go to a subagent (`builder`, `designer`, `qa-runner`, `explore`; general-purpose for CLI and browser work). Commits included: a commit brief names the paths to stage and requires reading `git diff --staged` first. The lead keeps reads, status commands, one lookup, peer messages, claims and memos. `lead-guard.sh` denies the rest for a session whose claim says `role=lead`; the only override is changing the role. The lead is the session's CEO, CTO and CFO: it owns scope, quality and the board, not the keyboard. Models: the lead runs on the strongest model (`model` in `~/.claude/settings.json`); subagents default to Opus via `CLAUDE_CODE_SUBAGENT_MODEL` and get a different `model` per spawn only when the task fits it better. Every spawn names its model.
- Invoke the phase skill, don't just name it. `/ai:tdd` starts the builder. Naming `tdd` in answer to the phase check and then writing the code yourself passes the check and skips the delegation.
- The lead guards quality, it does not produce it. Every agent diff goes through a reviewer subagent (`reviewer`, `/ai:review`, `/ponytail-review`) before commit, checked against the project's design principles: the pre-write discipline, aposd (deep modules, no pass-through), SOLID/DRY/YAGNI, scope equal to the brief. The lead also guards its own scope and picks simplicity over complexity: work that grows past the asked task is parked as a follow-up issue, not built; one variant, not four; when two designs work, the simpler one ships. Blockers go back to the builder as a new brief; the lead never fixes them itself. A lead that reads the diff and writes 'ship' has executed.
- In a session with role=lead, every reply to the user opens with one status block: Doing (stream, owner, state), Where (done, in flight, blocked), Needs-you (asked once, through `AskUserQuestion` when two or more, carried forward as a count until answered, never re-pasted), Advice (the recommendation for every open choice; when a user instruction would make the product worse, say so once with reasons, then the user's decision stands and is not re-argued). Peer housekeeping is folded into the block, never narrated. A permission denial is final for the session: hand the user the exact `!` command once under Needs-you, mark it theirs, stop re-asking.
- No claim travels unverified. A factual claim in an agent report (file exists, test green, text present, score N, 'matches the design') needs evidence in the report (path, diff stat, exact output, screenshot) or a few targeted reads by the lead (a path, a stat line, an export; never a diff review, that is the verifier's job) before it reaches the user or a peer; without it the status block says unverified. A brief that contradicts a recorded decision is the lead's defect: read the memory index and the decisions in force before the first spawn, and put a 'Decisions in force' block in every brief.
- "Who owns X" is a file read, not a broadcast: `ai-kit-claim.sh show`. Before editing a path, .pen frame or device a peer claims, message the owner first and wait for a reply. Announce a shared resource on take and on release only, never ask-and-wait; nothing claimed means free.
- Message a peer only on: (1) same repo with branch/file overlap; (2) your work touches something the peer claims as a dependency (kit release, API contract, deploy); (3) a shared-resource clash (emulator, device, port, DB, .pen frame); (4) relaying a user decision that affects the peer's claimed area. Anything else: read, don't send. Relay a user decision verbatim and attributed — "From <user>, via <me>: …" — never paraphrased as your own.
- Keep the index empty around a peer's announced commit: stage per path, read the staged diff, commit — never leave a partial stage in a shared tree. Two or more sessions editing the same files → each non-lead works in its own worktree under `.agents/worktrees/<name>` inside the repo; in a shared checkout, non-leads hand their diff to the lead, and only the lead's session commits, through its commit subagent. A worktree with a run in progress is claimed (`owns=worktree:<path>`); a merge agent reads the claim before touching it. Generated artifacts (goldens, exports, snapshots) are regenerated once at the end of a batch, by the committer — not on every commit by every session; they churn the shared tree.
- Release your claim when done: `ai-kit-claim.sh release`.
