---
name: prod-watch
description: Keeps a session open for hours as a proactive production-incident lead — polls error tracking and server logs on a self-pacing loop, triages findings with a debugging sub-agent before proposing a fix, and ships fixes through PR plus an explicit human go for every merge and deploy. Use when the user asks to monitor production, keep an eye on prod, or wants a session to stay open tracking error/server health across a work day — especially the day after an incident or risky deploy.
---

# Prod-watch

> **Status:** proposed 2026-05-24, harvested from a single real ~9.5-hour
> session on `emeq/system` the day after a zero-downtime-deploy cutover
> (evidence: that repo's `docs/reviews/2026-09-15-prod-watch.md`). Found and
> shipped 4 fixed-and-deployed findings, 1 merged test-only fix, and 1 filed
> non-urgent issue — three of those six had a root cause different from what
> the symptom suggested. Not yet run a second time; treat the specifics below
> as evidence-based defaults, not settled law.

Turns a session into a day-long production watch: poll → triage → fix with
approval → report. The point is not "run some checks periodically" — a cron
job does that. The point is a session that stays cheap while idle, gets
noisy fast the moment something real happens, never guesses a root cause it
could instead verify, and never takes an irreversible action without a fresh
"go" for that specific action.

## Relationship to `/loop`

Unlike [`autonomous`](../autonomous/SKILL.md), this skill's whole value is
*adaptive* pacing — tighten to ~15 minutes while something is open, relax
toward 20–30 minutes on a sustained clean streak. That needs dynamic
self-pacing, so — deliberately the opposite of `autonomous`'s rule — this
skill **does** call `ScheduleWakeup` itself, once per cycle, to decide its
own next wake time. Invoke it as `/loop /ai:prod-watch` (dynamic mode, no
fixed interval) rather than a fixed-interval `/loop 900s ...`; a fixed
external interval fights the self-pacing this skill exists to do.

## 0. Grill before starting — do not skip

Every project this skill will run in has some version of "never touch the
production server without per-command approval." A day-long poll cannot ask
permission every cycle, so this gate exists to resolve that collision
*once*, explicitly, before the loop starts unattended — not to slow things
down for its own sake. Ask, in one batch:

1. **Server access.** Propose a short, named whitelist of **read-only**
   commands only (log tail, error-level grep, process/supervisor status,
   disk/memory) and get one-time sign-off on the literal list. Never widen
   it later without asking again; never put a write command on it, ever —
   if the loop later wants to *change* something on the server (patch a
   deploy script, clear a stuck job), that is a new, separate approval, not
   an extension of the read-only whitelist.
2. **Error-tracking scope.** Which project(s)/org.
3. **Escalation threshold.** Recommend: new/unknown issue or a spike in a
   known one → interrupt immediately; known/noise → log only, report at the
   end.
4. **Deliverable.** A markdown report is the default; ask if they also want
   a skill/rule draft out of whatever gets found (that's this file's own
   origin).

Don't proceed past this implicitly, even under visible time pressure — the
access-model answer guards a hard safety rule the rest of the loop leans on.

## 1. The loop — one cycle per fire

Each `/loop` fire does exactly this, then exits:

1. Query the error tracker for unresolved issues in a short window (e.g.
   24h), diffed against the last cycle's known-issue list — not the whole
   history every time.
2. Run the approved read-only server checks.
3. Compare against the *previous cycle only*. Once a baseline exists, don't
   re-dig historical log content on every tick — that's wasted read volume,
   and in the source session the user explicitly had to say "stop
   re-checking the past, only watch forward from now."
4. New/unknown finding → stop, interrupt with a short plain-language
   explanation **plus a recommendation** ("fix now" / "park for the
   report"), never a bare "what should I do?" — a lead engineer who only
   surfaces problems and never has an opinion is not actually leading.
   Known/noise → append one line to the report's cycle log, no interruption.
5. Call `ScheduleWakeup`: tighten toward ~15 min while something is open or
   being fixed, relax toward the 20–30 min ceiling on a sustained clean
   streak. A long streak of identical clean cycles is the loop doing its
   job, not a sign it should stop — the value is entirely in not missing the
   one cycle that isn't clean, and you can't know in advance which one that
   is.
6. If a question was already asked and is still open, don't re-ask it every
   cycle — note it's pending and keep polling. Re-asking trains the user to
   ignore the loop's messages.

## 2. Triage: root-cause before proposing a fix

When a finding needs analysis, dispatch a dedicated debugging sub-agent
(isolated context) with the full grounded brief: what's known, what's
already ruled out, exact file:line evidence gathered so far, and explicit
permission boundaries (read-only unless told otherwise). Do not guess the
fix from the symptom.

In the source session, three of six findings had a root cause different from
what the symptom suggested — a "broken image in a generated PDF" turned out
to be a PDF-rendering sandbox check colliding with the app's own deploy
symlink layout, not the upload bug that was fixed first and looked like it
should have been the whole story; two "product bug" test failures turned out
to be a pagination collision with real seeded data, not the accounting logic
the failing assertions named. Verify hypotheses by reproducing live and
read-only against the real environment wherever the access whitelist allows
it, not by reading code and assuming the obvious story is the true one.

## 3. Fixing: sub-agent, worktree isolation, PR, never auto-merge

- Dispatch a builder-type sub-agent with worktree isolation if the main loop
  might touch the same repo concurrently — it usually will, since the loop
  keeps polling while a fix is in flight.
- TDD: a red test proving the bug, green after the fix, then the fix's local
  domain's full test suite (not just the newly-targeted test) before calling
  it done.
- Run the repo's own pre-commit review gate before committing. A sub-agent
  without the `Skill` tool cannot invoke a hook-gated skill itself — hand
  control back to the parent session to run it and unblock the commit; never
  fake the hook's marker file to get past it.
- Open a PR. **Never merge to the default branch without an explicit, fresh
  "go" from the user for that specific PR** — a standing "go" earlier in the
  session does not carry forward to the next merge, even a same-day,
  low-risk one. This held for every merge across the whole source session.
- After merge, only deploy if the user separately confirms it's needed — a
  test-only fix doesn't need a deploy, and saying so out loud avoids an
  unwanted deploy landing on reflex.

## 4. Deploys run in a separate agent

Once a deploy is approved, dispatch the deploy command to a background agent
instead of running it inline — a deploy with a build step can take minutes,
and running it in the main session blocks the loop and blocks responding to
the user for that whole window. Have the dispatched agent do its own
read-only post-deploy verification (release/symlink target, process status,
an HTTP health check) and report back; the parent session relays the result
and resumes the loop. This is a standing instruction worth confirming with
the user once, early, rather than re-litigating per deploy.

## 5. Vertical-slice verification

A fix is not done when the reported symptom's own test passes. Walk the
entire produce → consume chain a real user experiences (upload → generate →
view; write → read back; submit → confirm) before calling a user-facing fix
complete. A unit-level pass on the first step of that chain can hide a
second, unrelated bug further down that looks identical from the outside —
the source session's biggest process correction was exactly this: an
upload-format fix alone left the feature just as broken from the user's
point of view, for a completely different reason, for several more hours,
because nobody had checked the last step of the chain yet.

## 6. Peer-session coordination

If other sessions are working on related repos on the same infrastructure
(check with `ListAgents`), proactively share cross-cutting findings — shared
server, shared deploy pattern, shared upstream dependency — don't wait to be
asked. When a peer reports a claim back, verify it yourself before restating
it as fact to the user if you can (re-check the specific log line, re-run
the specific test) rather than passing it through unchecked. Never take an
action in a peer's repo yourself; hand back the concrete next step for them
to run in their own session and permission scope.

## 7. End-of-day report

Markdown file (`docs/reviews/<date>-<scope>.md` fits most repo conventions).
Structure:

- One paragraph of intent, plus the approved read-only whitelist — this is
  the audit trail for the one access decision the whole day's autonomy rests
  on.
- A findings table: what, root cause, status, PR, deployed y/n. This is the
  part a human reads first and sometimes only.
- One subsection per finding with the full trace: what looked true first,
  what was actually true, the evidence, the fix, how it was verified. This
  is what makes the report a real postmortem — and future training data for
  the next `prod-watch` run — rather than a changelog.
- A terse, timestamped cycle log — the boring proof nothing was missed
  during the quiet stretches.
- What's still open, named explicitly, so nothing quietly drops when the
  session ends.

## Anti-patterns caught mid-session

- Escalating on the first sign of a finding without reading the actual code
  path first — read the domain code before proposing, not after.
- Re-litigating an already-open question every single cycle instead of
  noting it pending and moving on.
- Treating a long run of identical clean cycles as a signal the loop should
  stop, rather than as the steady state it exists to prove.
- Fixing the reported symptom and calling it done without walking the full
  user-facing chain (§5).
- Letting an earlier "go" for one merge or deploy quietly cover the next
  one — each is its own approval.
