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
- "Who owns X" is a file read, not a broadcast: `ai-kit-claim.sh show`. Before editing a path, .pen frame or device a peer claims, message the owner first and wait for a reply.
- Message a peer only on: (1) same repo with branch/file overlap; (2) your work touches something the peer claims as a dependency (kit release, API contract, deploy); (3) a shared-resource clash (emulator, device, port, DB, .pen frame); (4) relaying a user decision that affects the peer's claimed area. Anything else: read, don't send.
- Relay a user decision verbatim and attributed — "From <user>, via <me>: …" — never paraphrased as your own.
- Keep the index empty around a peer's announced commit: stage per path, read the staged diff, commit — never leave a partial stage in a shared tree. Two or more sessions editing the same files → each non-lead works in its own worktree under `.agents/worktrees/<name>` inside the repo; in a shared checkout, non-leads hand their diff to the lead and only the lead commits.
- Generated artifacts (goldens, exports, snapshots) are regenerated once at the end of a batch, by the committer — not on every commit by every session; they churn the shared tree.
- Release your claim when done: `ai-kit-claim.sh release`.
