# Changelog

## 1.67.1 — 2026-08-28

### Fixed

- **The single-committer warning pointed at a file the check never opened**
  ([#151](https://github.com/yusufkaracaburun/ai-kit/issues/151)). It told you
  to document reviewer cadence in `CLAUDE.md`, and `grep -n CLAUDE
  bin/ai-kit-doctor.sh` returned three hits — two `GLOBAL_CLAUDE`, and the
  warning string itself. The file was never read, so the advice was
  unfollowable: on a solo repo the check cleared only when a second committer
  email appeared in the last 30 days, which no amount of documentation
  produces.

  `/ai:hygiene` inherited it. Each warning-exit section deducts 5 and prints
  `+5 resolve warning in <name>`, so every solo repo with 5 or more commits in
  30 days sat permanently at 95/100 while the report presented 100 as
  reachable. That is the part that wasted time — the recipe read as actionable.

  One committer is a fact about the repo, not something documentation can
  change, so the check now tests the mitigation instead: is there a written
  review practice supplying the second pass? It greps `CLAUDE.md` and
  `AGENTS.md` for the phrasing the warning itself proposes, passes when found,
  and when absent names the markers so the remediation is concrete. This repo
  already carried "Run `/ai:review` before a release" and now reports `ok
  single committer in last 30d (105 commits) — reviewer cadence documented`.

  Scope held to the reported check. The generic `+5 resolve warning in <name>`
  recipe is untouched: there is no evidence yet that another section is
  unactionable in the same way, and inventing one is how a kit grows rules
  nobody asked for.

## 1.67.0 — 2026-08-28

### Added

- **`design-tokens`, harvested from a build-time token check.** First
  `/ai:harvest` run, against an Astro content site. Tokens are generated from
  the design file on the build path, and the same step fails the build when a
  stylesheet references a token the design file does not define. The source
  repo's own comment names why that check has to exist: `var(--typo)` throws
  nothing, the declaration is dropped, the element falls back to an inherited
  value, and the page renders nearly right with no error anywhere. Type
  checkers do not see inside `var()`, and linters flag malformed values rather
  than missing ones.

  Added as its own rule rather than merged into `tailwind.mini.md`, which
  covers only the opposite direction (tokens defined with zero uses) and only
  for Tailwind — while the repo the pattern came from has no Tailwind at all.
  Merging would have locked the knowledge behind a framework the source does
  not use, which is the failed transfer `public-surface` came out of.
  Cross-linked both ways instead. Scoped `universal: false`, frontend.

### Changed

- **`laravel-conventions` gains tenant-scoped uniqueness.** Second harvest
  run. Two silent failures of the same shape, neither previously covered: a
  globally unique column on a tenant-owned table works until the second tenant
  picks a value the first already used, then fails as a constraint violation
  on a value that tenant has never seen; and a fixture with one tenant passes
  whether or not scoping works, because there is nothing to leak — the test
  proves nothing while looking like coverage.

  Merged rather than added. The rule already owned multi-tenancy and
  `code-audit-laravel` carries the L12 tenant-bleed heuristic, so a second rule
  would have split one concern across two files.

- **`harvest` documents the merge path.** Found by using it: the second run
  ended in a merge, which step 3 explicitly prefers, but steps 5 and 6 only
  described the new-rule path — walking you into a frontmatter block and a
  count guard that cannot fire, because the rule total never moved. Step 5 now
  branches at the top; step 6 splits into both landings and says which checks
  stay silent.

## 1.66.0 — 2026-08-27

### Added

- **`harvest`, the app → kit backflow.** Every other path in this kit runs
  kit → app. `contribute-eval` was the only way back and it captures the
  kit's own skill failures, never an app's wins — so an app could solve
  something better than the kit knew how, and the next app still started
  from zero. `public-surface` in v1.65.0 came out of exactly that gap: two
  repos had solved the same problem separately while a stack-scoped rule
  already carried half the answer without ever crossing the stack boundary.

  The skill encodes the judgment rather than the mechanics, because the
  mechanics were never the hard part. Three bar criteria — shipped, guarded
  by something that fails when it breaks, and would have applied in a second
  repo the user actually owns — and four judgment calls: what generalises
  once the stack is stripped, which `universal` flag (`emit-rules.sh`
  selects on that alone, so always-on is a claim about every future
  project), which existing rule already half-covers it, and what the sharp
  core is. That last one carries the most weight: a harvested rule that
  reads as a checklist wasted the harvest, because the value is the failure
  that passes silently, not the list of things to remember.

  It deliberately does not use `promotion-quorum.md`'s two-source bar. That
  governs external material, where independent sources substitute for trust.
  Here the evidence is your own running code, which is stronger — but only
  when it actually ships and something actually guards it.

  Routes away from the three adjacent skills rather than overlapping them:
  `contribute-eval` for the kit's failures, `should-i-use` and
  `recommend-rules` for external material, and nothing at all for fixes that
  only make sense in one repo. The eval fixture covers the rejection path,
  since failing criterion 3 is the common case and the skill working as
  intended.

## 1.65.0 — 2026-08-27

### Added

- **`public-surface`, a rule for any app that serves crawlable HTML.** Harvested
  from a shipped app rather than authored from theory. `emeq-hub` had
  independently built a public-surface layer — a server-side meta and schema
  builder, a sitemap derived from real routes, an environment-aware
  `robots.txt`, and a 264-line CI-gated regression suite — and no ai-kit rule
  covered any of it. `astro-conventions` carried an SEO baseline, but scoped to
  Astro, so it never crossed the stack boundary into a Laravel + Inertia app.
  The same problem was solved twice, from scratch, in two repos.

  The rule's core is the hydration trap. In Inertia, Next, Nuxt, Remix and
  SSR-mode Astro, a test that inspects props or the page object passes whether
  or not the server rendered HTML, and most frameworks fall back to client-side
  rendering silently by design — right for users, wrong for crawlers. The two
  defaults compose into a failure with no symptom: the suite stays green, the
  health endpoint returns 200, the deploy prints its checkmark, and crawlers
  receive an empty shell. Hence the rule's two demands that the surrounding
  rules did not make: assert the raw response body rather than framework state,
  and let deploy verification reach the rendered page rather than `/up`.

  Scoped `universal: false`, so API-only services and auth-gated internal tools
  do not carry it in context. It reaches a project through
  `/ai:recommend-rules` or an explicit `--rules public-surface`.

### Changed

- **`claude-seo` recorded as Ignore in `standards/external/plugins-excluded.json`.**
  Evaluated against `emeq-hub`, which does have a real organic surface —
  public routes, a dynamic sitemap, `robots.txt` and `llms.txt`. Ignored on
  category and cost: right tool for an SEO agency, wrong one for a
  dev-lifecycle kit, and the repo already covers the technical and GEO baseline
  with CI assertions rather than periodic audits. The evaluation surfaced one
  real gap, and it was a deploy-verification gap rather than an SEO-knowledge
  gap. `public-surface` above is that finding, generalised.

## 1.64.1 — 2026-08-27

### Fixed

- **`/ai:upgrade` never showed its release notes to anyone installing via the
  plugin.** The feature was written, documented and dead. `commands/upgrade.md`
  promises that the script "slices the relevant section out of `CHANGELOG.md`
  and prints it so the user sees what changed", and `ai-kit-upgrade.sh`
  implements exactly that.

  It reads `$AIKIT/CHANGELOG.md`. For a clone `$AIKIT` is the repo root and the
  file is there. For a plugin install `$AIKIT` is the plugin root, which is
  `workflow/`, and the changelog lives one level up, so it was never in the
  payload. The lookup hit `if not p.is_file(): sys.exit(0)` and the command
  printed a bare `Upgraded marker X -> Y` with no sign that anything had been
  withheld. Reproduced with one marker and two installs side by side: the clone
  printed the v1.64.0 notes, the plugin printed nothing.

  Same bug class as the orchestration mirror, whose own comment in `release.sh`
  already records it: a source-of-truth file that never reached the plugin
  payload, so the plugin-side script silently did nothing. Fixed the same way.
  `release.sh` now copies `CHANGELOG.md` into `workflow/` and stages it; the
  script is unchanged, since the existing lookup resolves once the file is
  there. Guarded in `tests/bin/cases/structure.sh`, which requires the payload
  to carry a changelog byte-identical to the root one.

  This release is the first upgrade that prints its own notes.

## 1.64.0 — 2026-08-27

### Added

- **`show-me`, a skill that answers with a drawing instead of a paragraph.**
  A paragraph describing a call chain is slower to read than the call chain.
  The skill carries seven views, a call tree, a component tree, a shallow file
  tree, pseudocode, a shaped diff, a Mermaid diagram, or one focused HTML page,
  and a decision table that picks the smallest one that answers the question.
  It sits next to `zoom-out` without duplicating it: `zoom-out` is manual-only
  and answers with a prose map, `show-me` is model-invocable and draws the
  shape.

  The idea comes from [humanlayer/skills](https://github.com/humanlayer/skills)
  plugin `show-me` (MIT, commit `3c2629142c5d437428269b1b722b08c0b87f574d`),
  adopted as a pattern rather than wired. It is 100 lines of markdown with no
  code, so a second marketplace for every developer to add, upstream drift to
  track, and a macOS-only `open` all cost more than owning the idea. The view
  set and the smallest-view-that-answers rule are credited in the skill's
  provenance block; the text, decision table, rules and examples are ai-kit's.
  Deliberately absent from `vendored.json`, which tracks verbatim copies for
  upstream-drift to chase, and recorded in `plugins-excluded.json` so a later
  `/ai:should-i-use humanlayer/skills` cannot recommend installing what the kit
  already ships.

  The HTML branch writes to the OS temp directory, never the repo. Pre-release
  review caught the omission: a page filled with the project's real data and no
  stated write path defaults to the consumer's repo root, one `git add -A` from
  being committed. It now mirrors `improve-codebase-architecture`, which had
  already solved the same problem.

- **`web-quality-skills` in the plugin catalog**, and `ui-skills` plus
  `frontend-design-toolkit` recorded as deliberate exclusions. A recursive grep
  for core web vitals, Lighthouse, LCP, CLS and INP across `standards`,
  `workflow`, `context`, `orchestration` and `docs` found nothing, so the
  performance-budget gap was real. The toolkit that surfaced it is itself
  excluded: its own stacks were already covered, and it fails VETTING #3 on its
  own content, attributing Chrome DevTools MCP to Anthropic with an install
  command that 404s on npm and contradicting its own star count inside one file.

- **Two `should-i-use` verdicts recorded**, both Ignore, both against tools that
  looked in-category. `skill-doctor` (warpdotdev/common-skills) duplicates a
  first-party feature, ships a vendor CTA its SKILL.md tells the agent to append
  to every response, and carries a 1.1 MB minified bundle with no licence header
  anywhere in the repo. `show-me` as a plugin, per above.

  The `skill-doctor` entry landed under commit `0a217e4`, whose message covers
  only the catalog work: two sessions were writing the same ledger and one
  staged the other's uncommitted change without reading the staged diff.

### Changed

- Skill count moves from 39 to 40 across the README, ONBOARDING, the docs, both
  plugin manifests, and the two count assertions. `bin/count-primitives.sh`
  guards a `| Skills | N |` table row in the README that a prose grep for
  "39 skills" does not catch.

## 1.63.1 — 2026-08-27

### Fixed

- **The installer could not repair the links it had made.** `install_dir_to`
  and `install_files_to` refuse to clobber whatever already sits at a
  destination, and a dead symlink read as "already there": `cd` into a broken
  link fails, `resolved` comes back empty, and empty matches no `$src_real`
  prefix, so the entry fell through to `Skipped … (existing non-aikit entry)`
  and stayed dead. Move the ai-kit root and every link it ever made is
  stranded — rerunning the installer changed nothing and said so once per
  link. On the machine this was found on: 44 in `~/.agents/skills`, 23 in
  `~/.cursor/skills`, 7 in `~/.cursor/commands`, all pointing at a
  `~/.local/share/ai-kit` that had not existed for months. Both functions now
  sweep their target directory before the entry loop and delete dead links
  they can prove are ai-kit's. Running first is what makes the sweep reach
  rename orphans — `aikit-tdd`, `followup`, `handoff` — whose names left the
  source tree, so the entry loop, which only ever walks names that still
  exist, would never visit them again.

  Proving ownership takes two patterns, because one covers only half the
  installs. `*/ai-kit/*` catches a clone. It cannot catch a plugin install,
  whose root pins the version into the path
  (`~/.claude/plugins/cache/<owner>/ai/1.63.0`) and therefore carries no
  `/ai-kit/` segment at all — and that is exactly the root whose links go
  dead on every upgrade, in the three directories the `prefer-plugin` marker
  does not skip. The second pattern is the previous value of
  `~/.config/ai-kit/root`, read before `write_ai_kit_root_config` overwrites
  it. It falls back to a sentinel when that file is absent: an empty value
  would expand the case arm to `/*`, which matches every absolute path,
  including links belonging to other tools. Dead links ai-kit cannot claim
  are left exactly where they are.

- **A diagnostic in the test harness could kill the case it was explaining.**
  `_assert_show` truncates a long value at twelve lines, then greps the tail
  for `warn`/`err`/`fail`, because the line that explains a failure is rarely
  in the first twelve. That grep exits 1 when the tail holds no such line,
  and every case file runs under `set -e`, so the assignment took the whole
  case down mid-run: no further asserts, no summary, no exit code, and the
  failure it was halfway through printing lost with it. A review of
  `install-global.sh` hit this and stopped at assert 23 of 26 with nothing to
  say it had stopped early. The comment eight lines below already stated the
  rule that was being broken: never let diagnostics decide the run.

## 1.63.0 — 2026-08-27

### Added

- **Vendored upstreams are pinned, and something finally reads the pin.**
  ai-kit carries verbatim copies of a few upstream files — the Sandcastle
  sequential-reviewer templates, the copywriter skill, one external Cursor
  rule. `standards/external/VETTING.md` has asked for `source_url` /
  `source_license` / `pinned_sha` / `vendored_at` since 1.15, but nothing
  ever read those fields: `grep -rn pinned_sha bin/` returned zero hits. A
  pin nobody checks is decoration. New `standards/external/vendored.json`
  records one entry per verbatim copy, and `bin/ai-kit-upstream-drift.sh`
  compares each pin against `git ls-remote`, printing a GitHub compare URL
  when they differ. Report-only, exit 0 by default (matching dedupe and
  audit-ecosystem); `--strict` exits 1 for CI. An unreachable upstream is
  reported as unchecked, never as a failure — an offline laptop must not
  break a hygiene run.

  Each entry carries `local_deltas`: the edits ai-kit made on purpose. The
  Sandcastle copy is not a clean fork — `main.mts` has `{{INSTALL_CMD}}` /
  `{{COPY_TO_WORKTREE}}` placeholders that `apply-sandcastle.sh` fills from
  lockfile detection. A blind re-vendor would silently re-hardcode npm for
  every PHP project. Distilled work stays out of the manifest by design:
  the lifecycle skills whose ideas came from `mattpocock/skills`, gstack and
  superpowers are deliberately divergent, and resyncing them would undo the
  distillation `plugins-excluded.json` records as intentional.

- **`/ai:hygiene` gained an eighth section**, `upstream-drift`, guarded on
  the manifest existing so it stays silent in consumer projects — they
  vendor nothing. Upstream moving costs no score: it is information for a
  human, not an install defect.

### Fixed

- **The Sandcastle reviewer was reviewing an empty diff.** `review-prompt.md`
  asked for `git diff {{SOURCE_BRANCH}}...{{BRANCH}}`. Sandcastle injects
  both `SOURCE_BRANCH` and `TARGET_BRANCH`, and `SOURCE_BRANCH` equals
  `BRANCH` at run time — so the diff was always empty and the review agent
  reviewed nothing, every iteration, while reporting success. Upstream's own
  test now asserts the template does not contain `{{SOURCE_BRANCH}}` for
  exactly this reason. Re-vendored from 65063f6 to e99f832, which also
  brings `maxIterations: 100 → 1` on the implementer (100 let one agent
  drain the whole backlog onto a single branch, defeating the per-issue
  review the template exists for), `continue → break` when an implement
  phase produces no commits (it used to spin the outer loop
  MAX_ITERATIONS times over an empty backlog), and a prompt statement that
  the issue list is pre-filtered and is the sole source of truth.

  Both local deltas were reapplied and verified: our tree differs from
  upstream at the new pin by those two deltas and nothing else.

- **`/ai:setup` branch 8 scaffolded an empty directory for plugin installs.**
  `bin/apply-sandcastle.sh` resolves `$AIKIT` from its own location, so from
  `workflow/bin/` it looked for `workflow/orchestration/sandcastle/` — a
  directory that never existed. The `cp` failures are swallowed by
  `2>/dev/null || true`, and the script still printed "Sandcastle scaffold
  installed". Four sibling mirrors existed (bin, hooks, standards, context);
  orchestration was never added to the set. New
  `bin/sync-plugin-orchestration.sh`, wired into `bin/release.sh` — both the
  sync call and `workflow/orchestration` in the release commit's `git add`,
  since a mirror that is re-stamped but never staged drifts straight back.

  The regression guard is behavioural rather than another `--check`: a
  `--check` only catches drift in a mirror that exists, and this one was
  absent for five releases without anything complaining. `structure.sh` now
  runs the plugin-side script and requires a non-empty scaffold with no
  unresolved placeholders.

- **Argument injection in the new drift check.** Found by `/ai:review`
  before release, not after. `git ls-remote "$repo" "$ref"` had no `--`
  separator, so a `repo` value starting with `-` was read as a git option —
  `--upload-pack=<cmd>` turns an edit to a JSON data file into command
  execution on every `/ai:hygiene` run. Reproduced against a scratch repo,
  fixed with `ls-remote --`, and locked with a regression test that goes red
  when the `--` is removed. Exploiting it needs commit access to ai-kit's own
  manifest, so it is defense-in-depth rather than a live privilege boundary.

  The same call now runs `GIT_TERMINAL_PROMPT=0 git -c credential.helper=`:
  when an upstream goes private GitHub answers 401, git invokes the
  credential helper, and a section documented as report-only would block on
  an interactive auth dialog. The manifest pins a branch on a personal repo —
  exactly the ref that disappears.

- **`to-issues` pointed at `/setup-matt-pocock-skills`**, a command that does
  not exist. 1.62.0 fixed the same dangling reference in `triage` and missed
  this one. Now points at `docs/agents/triage-labels.md`, which
  `bootstrap-project.sh` writes.

### Changed

- **`laravel-php-83` external rule re-pinned** `4467ad4` → `b044f95` with no
  content change: the repo HEAD had moved but zero commits touched that file
  and its body compared identical, so only the pin advanced. That file
  records the pin a second time in its own frontmatter, and two records of
  one fact drift — a new assert requires every vendored `.md`'s frontmatter
  `pinned_sha` to equal the manifest's.

- **`vendored.json` joins `plugins-excluded.json`** on the symmetry audit's
  excluded list. Both have a consumer, just not a setup-branch one; it
  describes ai-kit itself rather than the project being set up, so a setup
  branch would have nothing to ask.

Tests: 1254 pass (was 1229).

## 1.62.0 — 2026-08-27

### Fixed

- **The AFK queue was permanently empty on a fresh install.**
  `bin/autonomous-queue.sh` filters issues on `ready-for-agent` and
  `bin/ai-kit-next.sh` scores the triage labels, but
  `context/templates/github/labels.json` only ever shipped `P0-P3` / `epic/*` /
  `area/*` / `status:in-progress`. Nothing created the label the tooling
  queried, so `/ai:autonomous` drained nothing and `/ai:next` scored a label
  no issue could carry. The catalog now ships all five triage roles
  (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`,
  `wontfix`).

  A new `label-catalog contract` test asserts the invariant that was missing:
  every label the tooling queries must exist in the catalog, and every
  `P`-label must satisfy the `/^P[0-3]-/` regex `auto-promote-ready.yml`
  matches on — otherwise a correctly-labelled issue never promotes
  Todo → Ready.

- **Two agent docs were verified but never produced.**
  `bin/verify-setup.sh` checks `docs/agents/workflow.md` and
  `docs/agents/triage-labels.md`; no script wrote either. A verifier without a
  producer is a drift generator — it fails on every project and teaches people
  to ignore it. `bin/bootstrap-project.sh` now copies both, so the agile
  framework and the label mapping exist before any skill reads them.

- **`.github/workflows/gitleaks.yml` — same class of bug.**
  `bin/ai-kit-secrets-gate.sh` warns when the file is absent and the template
  had shipped all along, but nothing copied it. Now scaffolded alongside the
  other two workflows, GitHub remotes only, never overwriting. A new
  end-to-end assert requires the gate to exit 0 on a repo
  `setup-gh-workflow.sh` just scaffolded.

- **`triage` pointed at a command that does not exist.** The skill told the
  agent to run `/setup-matt-pocock-skills` to obtain the label mapping. It now
  points at `docs/agents/triage-labels.md`, which bootstrap writes.

### Added

- **`/ai:setup` branch 9 (Agile workflow) has a procedure.** It was a row in
  the Tier-B table with no body anywhere in the repo — the agent improvised at
  exactly the point where consistency matters. The branch now asks which
  framework the project runs, fills `docs/agents/workflow.md`, and prompts for
  the control each framework actually needs: a WIP limit for kanban, a sprint
  length for scrum. An unset WIP limit is the most common reason a kanban board
  quietly becomes a wishlist; `/ai:next` scores `status:in-progress` at +50 to
  nudge finish-before-start, but only the limit is a ceiling.

### Changed

- **`setup-gh-workflow` skill documents what its script already did.** The
  "What it installs" table gained the PR template, branch protection, and
  `gitleaks.yml`; the process list gained steps 5 and 6; the flags table gained
  `--no-pr-template` and `--no-protection`. The script's header comment was
  corrected in 1.59.0 but the skill body — the part the model reads — was not.

## 1.61.0 — 2026-08-27

### Added

- **Test coverage for 8 previously untested `bin/` scripts** — 102 assertions.
  The two that mattered most are the destructive ones: `ai-kit-migrate-gsd.sh`
  (236 lines, removes SessionStart hooks and gsd metadata from `~/.claude`) and
  `install-global.sh` (symlinks into `~/.claude`, `~/.agents`, `~/.cursor`). Also
  `audit-nextjs-helpers.sh`, `audit-shadcn-helpers.sh` (their react/typescript/
  laravel siblings already had cases), `ai-kit-memory-audit.sh`, `ai-kit-phase.sh`,
  `ai-kit-prefer-plugin.sh`, `autonomous-heartbeat.sh`. Every test that touches
  `$HOME` sandboxes it. Untested `bin/` lines dropped from 14.5% to ~4%.

- **`bin/hooks/session-rules-inject.sh`** — a `SessionStart` hook that injects a
  project's emitted `always-on`, `weight: high` rules into Claude Code, closing
  the gap where that mode meant real enforcement on Cursor and nothing here.
  Ships with `bin/ai-kit-no-rule-injection.sh` (machine-wide opt-out), a
  `context-lean` reconciliation, and 30 tests.

  **Not registered in `workflow/hooks/hooks.json`.** Measured against a real
  project before wiring it, and the measurement said no: the selection fills its
  word budget smallest-first, so within `weight: high` the shortest rules always
  win. `context-discipline` (512 words) and `domain-model-first` (726) were
  dropped for being long, not for being less important — length had become an
  inverse proxy for merit. Turning it on would add ~1,679 words (≈2.2–2.8k
  tokens) per session on top of the ~6,000–7,500 a project already carries.
  Tracked in **#148**; the wiring test pins the absence so it cannot be
  re-enabled by accident.

- **`bin/lib/emitters/README.md`** now documents `default_mode` per host, and
  `tests/bin/cases/default-mode-semantics.sh` fails if the two emitters ever
  diverge again on the same mode value.

### Fixed

- **The test runner counted a crashed case as zero instead of as a failure.**
  A case that dies under `set -e` before printing its `PASS:`/`FAIL:` line
  contributed nothing to either counter, so the summary read
  `N passed, 0 failed` directly beneath a `✗` line. The exit code was already
  1 — CI did go red — but the summary contradicted the detail above it. Now
  counted as one failure and named on stderr. (#145)

- **`docs-sync` offered live worktree branches for deletion.** git prefixes a
  branch checked out in a linked worktree with `+`; the strip only handled `*`
  and spaces, so such a branch was reported as a cleanup candidate under the
  name `+ <branch>` — an invalid name that `git branch -d` would have rejected
  anyway. (#145)

- **`release.sh` called a linked worktree "not a git repo"** — `.git` is a file
  there, not a directory. Uses `git rev-parse --git-dir`. (#145)

- **`ai-kit-doctor.sh` reported a running agent's test fixtures as project rot.**
  The broken-symlink scan walked `.claude/worktrees/`, which is transient,
  gitignored scratch space. Pruned alongside `node_modules` and `vendor`.

- **Review blockers in the new coverage cases.** The worst was process leakage:
  `autonomous-heartbeat.sh` started an unbounded `while true; sleep` loop in the
  background with no EXIT trap, orphaning a process that ticked every second
  forever on any early abort. Two of its cases ran that same loop in the
  *foreground*, and `run-all.sh` has no per-case timeout — a validation
  regression would have wedged the whole suite. Also: four tautological
  `RC=$?`-after-assignment assertions that could only ever pass, a
  `grep -qE "42.*heartbeat"` that also matched the timestamp (roughly one run in
  sixty passed with the wrong issue number), and an idempotency section that
  passed with the installer replaced by `true` — verified by doing exactly that.

### Changed

- **`tests/bin/run-all.sh` honours a `CASES` override**, same idiom as `JOBS`,
  so a test can point the runner at a throwaway cases directory instead of
  recursing into the real suite.

- **`.claude/worktrees/` is gitignored.** Agent worktrees are transient and were
  briefly tracked as embedded git repositories.

### Performance

- **`lifecycle.sh` went from the slowest case in the suite to 26s.** It called
  `bootstrap-project.sh` six times with identical arguments at ~7.7s each;
  `tests/bin/lib/fixtures.sh` now builds once per argument signature and copies
  the rest. The cost is fork overhead, not computation — 84% of that 7.7s is
  system time, since `emit-rules.sh` rebuilds the whole `active-rules.md` index
  per rule.

  Corrects an earlier count: `doctor-broken-symlinks.sh` calls bootstrap zero
  times, not three — the grep matched a string inside an assertion pattern. 19
  real invocations across 5 files, and only `lifecycle.sh`'s six were true
  duplicates; the rest vary flags or preconditions and cannot be cached without
  dropping what they test.

### Testing

- Suite: **1210 passed, 0 failed** (from 1080).
- 58 fixture-marker assertions in the three `audit-*-extension` cases collapsed
  to 4 counted ones. They asserted properties of *test data*, not of ai-kit code
  — a `git mv` broke them, a real bug did not. The negative api-only/full-stack
  markers stay: those encode a design invariant.
- Three near-clone extension cases merged into one table-driven
  `audit-extensions.sh`; five prose-lint cases merged into `two-dev-framing.sh`.
- Three tautological assertions elsewhere in the suite fixed rather than deleted.

## 1.60.0 — 2026-08-26

### Added

- **`ponytail` joins the companion catalog** (`DietrichGebert/ponytail` @ `2ed6c52`,
  MIT). A YAGNI ladder — does it need to exist → already in the codebase → stdlib →
  native platform → dependency → one line → minimum — injected at `SessionStart` and
  `SubagentStart`. Security, validation, error handling and accessibility are
  explicitly out of scope for the cut. It is **orthogonal to `caveman`, not an
  alternative**: caveman compresses what the agent says, ponytail constrains what it
  builds; upstream endorses running both.

  `bin/apply-ponytail.sh` adds the marketplace, installs via the official
  `claude plugin` CLI and writes ponytail's own `defaultMode` — idempotent, and
  machine-wide, so `/ai:setup` Branch 2e asks first (it already iterates
  `universal: true`, so no new branch was needed). No de-duplication guard, unlike
  `apply-caveman.sh`: ponytail ships no standalone hook installer, so there is
  nothing to double-fire.

### Changed

- **`plugins-excluded.json` gains a `reversed[]` array.** An Ignore verdict that
  silently disappears is worse than no ledger — the next person re-litigates it from
  scratch. Reversals now carry the evidence that overturned them.

- **`pre-write-discipline.mini.md` keeps `always-on`, and now says why per host.**
  It was briefly flipped to `on-demand` on the theory that ponytail had taken over the
  slot. Pre-release review caught that `bin/lib/emitters/cursor.sh` maps `always-on` to
  `alwaysApply: true`, so the flip would have emitted `alwaysApply: false` into every
  Cursor project while ai-kit's ponytail wiring is Claude-Code-only. Reverted. ponytail
  enforces on Claude Code, the mode enforces on Cursor — complementary, not a hand-off.

- **`caveman`'s catalog entry records its licence carve-out.** It is MIT for the
  plugin and skills but **BSL-1.1 for the Engine-linked directories** (`engine/`,
  `proxy/`, `cacheengine/`, `rewriter/`, `browse/`, `mcp/`, `shrink/`, cavemem Go
  core, `shared/platform/`); GitHub reports `NOASSERTION`. VETTING.md #4 requires a
  non-OSS tag on source-available dependencies and it had been missing since
  adoption. ai-kit wires the plugin and vendors nothing, so the BSL half is never
  redistributed — but the tag belongs in the entry.

### Fixed

- **ponytail's Ignore verdict (2026-07-25) reversed to Wire.** The verdict rested on
  one unverified claim: redundant with ai-kit's own always-on
  `pre-write-discipline`, so wiring ponytail would double-inject one discipline.
  Re-checked against the code: `workflow/.claude-plugin/plugin.json` declares no
  `hooks` key, `bin/lib/emitters/claude-code.sh` writes rules to
  `.claude/rules/<name>.md` — described in its own header as *"read by agent on
  demand"* — and `.claude/rules/` does not exist in this repo. `always-on` is a
  frontmatter label with no delivery mechanism behind it for Claude Code: 22 rules
  carry it, none inject. There was never any double injection to avoid.

  Measured against VETTING.md beside the already-adopted caveman: MIT with no
  carve-outs; benchmark suite checked in with named baselines and numbers the author
  revised **down** after upstream criticism; 112k stars / 63 contributors / 6160
  forks vs caveman's 101k / 33. Security (#8): a static skillspector scan returns
  `DO_NOT_INSTALL` with 27 HIGH — all triaged as noise, since **zero** findings land
  in the shipped runtime (`hooks/`, `skills/`, `bin/`) and every HIGH sits in
  `benchmarks/`, `tests/`, `README.md` or `docs/`. Hand-read of `hooks/*.js`: no
  network, no `child_process`, no credential env reads.

  Scope correction from that same review: the claim holds for Claude Code only. **30**
  rules carry `always-on` (22 in `standards/rules/`, 8 in `standards/rules/feedback/`),
  21 of them `universal` — and on Cursor the key is real enforcement. One frontmatter
  key meaning "enforced" on one host and "decorative" on the other is the actual defect,
  and it is not ponytail's job: **#144**.

### Testing

- `tests/bin/cases/apply-ponytail.sh` — 25 assertions covering status parsing,
  malformed-input refusal, mode validation, uninstall idempotency, and the two
  deliberate divergences from `apply-caveman.sh` (narrower mode set, no dedupe path).
- The fixture-marker enumerations in the three `audit-*-extension` cases collapse from
  58 assertions to 4 counted ones. They asserted properties of *test data*, not of
  ai-kit code — a `git mv` broke them, a real bug did not. The negative
  api-only/full-stack markers stay: those encode a design invariant.
- Suite: **1059 passed, 0 failed**.

## 1.59.1 — 2026-08-24

### Changed

- `tailwind.mini.md` gains an "Enforce it — a rule nobody counts drifts"
  section: grep the violations, commit today's count as a baseline, fail when
  the number rises. Legacy stays, new drift is blocked, so enforcement can
  start without a migration. Wire it into the project's `validate` chain **and**
  pre-commit **and** CI — two of three makes it advisory. Names the linter blind
  spot: `text-[#fff]` gets flagged, `text-emerald-600` does not, and the
  valid-but-untokenised class is the drift that accumulates.

- `standards/external/plugins-excluded.json`: `ui-ux-audit-command` recorded as
  **Ignore**. A pasted four-phase UI/UX-audit command (no upstream repo, no
  licence); three of its four phases duplicate `tailwind.mini.md`,
  `a11y.mini.md`, `/ai:qa`, `/ai:audit-architecture` and `prototype/UI.md`, and
  its Fase 2 wants a folder for gitignored licensed material. Measured against
  the intended target (emeq-app, 448 `.tsx`, 84 routes, Tailwind v4 `@theme` +
  142 custom properties): 2 hardcoded palette classes in 1 file, 0 arbitrary
  values — and its Fase 1 already exists there and stronger (`colors:check`,
  `token:freeze`, `ds:check` G0–G8, `parity:seed-design`, chained in
  `pnpm validate` behind husky and CI). The ratchet mechanic was adopted as a
  pattern instead, which is the `tailwind.mini.md` change above.

## 1.59.0 — 2026-08-24

### Added

- Behavioural eval layer via first-party `claude plugin eval` (spike #137,
  ADR-0002 revisited):
  - New `workflow/evals/` suite shipping inside the plugin — 3 cases
    (`grill-me-auth-rewrite`, `phase-flip-to-production` with scaffold,
    `copywriter-dutch-tells`), 14 graders. Fixture prompts reused from
    `tests/eval/prompts/`; each fixture-`expects` line became one grader
    (free regex/`tool_used` where checkable, haiku llm-judge for nuance).
  - Measured across 5 invocations: ≈ $2.5 token value per full suite run
    ($0 cash on a Max subscription), case-score spread 0.11–0.40 across
    identical invocations, ablation delta +0.29…+0.52 on every case,
    skill-fired indicator 24/24.
  - ADR-0002 "Revisited 2026-08-24": trigger half met — cheap yes,
    deterministic-enough-for-a-hard-gate no. `claude plugin eval` becomes
    the **advisory behavioural pass at release time**; structural checks
    remain the only hard CI gate. Re-evaluate hard-gating at GA.
  - The layer paid for itself on first contact: three real skill findings
    filed — copywriter §-citation drift (#138), a rule-of-three phrase
    surviving a rewrite (#138), and phase falling back to hand-editing the
    marker when `CLAUDE_PLUGIN_ROOT` doesn't resolve (#139).
  - `workflow/evals/results/` gitignored (mirrors `tests/eval/results/`).

### Changed

- `docs/diagrams.md`: wiring diagram compressed to the editorial 11-node view
  (three routes, three host groups, plugin route marked primary) — the cuts
  proven by the diagram-design smoke test, back-ported to the Mermaid source.
  Count-guard patterns intact; full per-surface wiring stays in
  `architecture.md`.

### Ledger

- `autoresearch-universal` (balukosuri repo, Karpathy-pattern prompt-mutation
  loop) recorded as Ignore in `standards/external/plugins-excluded.json`:
  licence-void, person/one-off scope, Goodhart risk on binary criteria,
  autonomous mutation of shipped skills vs. review culture. Its measurement
  want routed into the eval layer above instead.

## 1.58.0 — 2026-08-24

### Added

- Astro stack support, end to end (an Astro site is planned — emeq-web):
  - `detect-lib.sh` gains the `astro` framework signal (`"astro"` in
    `package.json`, same quoted-key pattern as `next`/`react`, so
    `astro-icon` does not false-positive) plus `docs.astro.build` in
    `docs_url_for`.
  - Catalog: `astro-docs` MCP entry (official `withastro/docs-mcp`,
    remote streamable HTTP, no API key, nothing runs locally) gated on
    the astro signal; `astro` also joins context7's framework signals as
    the universal fallback docs channel.
  - New rule `astro-conventions.mini.md` (canonical rules 34 → 35):
    static-first islands discipline (zero-JS budget, cheapest `client:*`
    directive that works), typed content collections, and an SEO baseline
    — `site` set, canonical per page, `@astrojs/sitemap`, `astro:assets`
    images, prerender-by-default. Fires via recommend-rules on astro
    repos.
  - Tests: new `detect-frameworks` section (astro detected, `astro-icon`
    no match, docs URL) and rule-count guards bumped.
  - Deliberately deferred: a `code-audit-astro` extension waits for the
    first real Astro repo to calibrate heuristics against.

### Changed

- `plugins-excluded.json`: `skills-cli` (vercel-labs/skills, the
  `npx skills` installer) ledgered as Ignore — duplicates the plugin
  marketplace distribution channel (this repo's own leftover caveman
  npx-skills install shadowed the caveman plugin), has no per-session
  compounding value, and publishing ai-kit itself through it would ship
  broken halves. Keeps its documented role as direct-install fallback
  for non-marketplace SKILL.md packs.

## 1.57.0 — 2026-08-23

### Added

- `content` signal type in the recommend-tools scorer: matches a literal
  substring against project markdown (bounded walk — dependency dirs skipped,
  200-file / 256KB caps). Complements the existing frameworks / architectures /
  files / git_remote_host / deploy_shape / dependencies / env signals.
- Catalog: `diagram-design` plugin (cathrynlavery/diagram-design, MIT, pinned
  `648c2a5`) in a new `diagrams` category, gated on `content:```mermaid` — only
  repos that already draw Mermaid diagrams get the recommendation. Vetted per
  VETTING.md (all eight criteria; skillspector static CRITICAL verdict triaged
  as 100% false positives — adversarial import-test fixtures and SVG example
  copy). Entry discloses that output is standalone HTML+SVG which GitHub does
  not render inline: Mermaid stays the in-repo source of truth, diagram-design
  is the publication-quality export path.

### Changed

- `plugins-excluded.json`: the same-session diagram-design Ignore entry is
  reversed — its "no detectable signal" ground is closed by the new `content`
  signal. Decision trail preserved in the VETTING.md audit row.

## 1.56.0 — 2026-08-20

### Fixed

- **The most-used signal in the MCP catalog was never read.** `dependencies` carries fourteen of the twenty-three entries in `standards/external/mcp-servers.json` — redis, sentry, stripe, supabase, postgresql, puppeteer, aws, cloudflare, slack, mysql, linear, firecrawl, exa — several of them with no other signal at all. The scorer handled frameworks, architectures, files, `git_remote_host`, `deploy_shape` and `env`; `dependencies` was not among them, and `detect-tooling.sh` never emitted the key it would have read. Every dependency-only entry scored zero and stayed under the surfacing threshold.

  Silent in the worst way, because a signal that is never read looks exactly like a project that genuinely does not match. A Laravel app with `predis/predis` in `composer.json` was told nothing about the redis MCP, and the output gave no hint that a question had gone unasked.

  `detect_dependencies` merges `package.json` (`dependencies` + `devDependencies`) with `composer.json` (`require` + `require-dev`). The bare `php` constraint is dropped: it is a platform requirement rather than a package, and would otherwise sit in every PHP project's list matching nothing.

  Matching is exact on the package name, slashes included, so `sentry/sentry-laravel` means that package. A catalog entry ending in `/` is the deliberate namespace form — `@aws-sdk/`, `@sentry/` — and prefix-matches instead. Without that split `redis` would fire on `redis-om`, which is the case the new assertions pin down.

  Weighted at three, level with frameworks. A declared dependency is a direct statement that the project uses the thing, which is stronger evidence than a file existing. Existing rankings do shift, but only because the signal was contributing nothing before — there is no prior weighting to preserve.

### Added

- **The Resend plugin is catalogued.** The ecosystem audit had been flagging `resend@claude-plugins-official` as ADOPT — installed at user scope, absent from the catalog — and the promotion had to wait for the signal above, because there was no honest way to express it. There is no marker file meaning "this project sends mail through Resend", and the `env` signal reads the agent's own process environment, so a project's `RESEND_API_KEY` in `.env` would never have matched.

  Keyed on `resend`, `resend/resend-php` and `resend-laravel`. A project using Resend purely over SMTP declares no package and correctly gets nothing: with no SDK in play there is no Resend-specific knowledge to offer.

### Notes

Six assertions were added to the `recommend` case, covering both match modes, the `php` exclusion, and the substring case that motivated the exact-versus-prefix split.

The `env` signal still reads the process environment rather than the project's `.env` files, and is left for its own release.

Tests: 1069 → 1075 passing.

## 1.55.1 — 2026-08-20

### Fixed

- **A test case was mutating the repository the other cases were reading.** `structure`'s drift block wrote `0.0.0-drift` into the real `workflow/.claude-plugin/plugin.json` and restored it three commands later, while the runner dispatches cases four at a time. Any case invoking `ai-kit-doctor.sh` inside that window read the corrupted manifest, got a warning, and exited 1 — which is every intermittent doctor failure seen on CI, including the one that made v1.55.0's own tag land on a red commit.

  Shared mutable state in a parallel suite, though it read as a platform quirk for weeks: the window is milliseconds wide, doctor run on its own never reproduced it, and it landed on whichever assertion happened to fall inside — `opt-out alone exits 0` one run, `project-only exit 0` the next. Reproduced locally for the first time by hammering doctor while the case runs: one failure in sixty with the old block, none in sixty with the new one, which matches the rate CI showed.

  `resolve_ai_kit_root` honours `AI_KIT_ROOT` ahead of script location, so the drift now happens in a throwaway root holding a copy of `VERSION` and the manifest. No change to `sync-plugin-version.sh`, and no serialising the suite to make one case safe. A new assertion checks the repo's own manifest survives the case, which is the property every other case depends on.

  Found by the failure diagnostics added one release earlier, on their first real failure — the log printed doctor's output and the offending line named itself. Without them it would have said only that a number was wrong.

- **A verdict line past the truncation cap is now surfaced.** Diagnosing the above still needed a manual log re-fetch: doctor's single `warn` sat on line 16 of 34 and the cap stopped at 15, so the answer was captured, printed, and cut off one line too early. The line that explains a failure is rarely in the first twelve. The tail is now scanned for `warn` / `err` / `fail` lines and up to five are shown beneath the elision marker.

### Notes

v1.55.0's tag points at a commit whose test run is red — from this flake rather than a regression. This release is the same content on a green one.

Tests: 1067 → 1069 passing.

## 1.55.0 — 2026-08-20

### Added

- **`/ai:hygiene` grades the secret-prevention wiring.** A seventh section, reporting whether the gate emitted in v1.54.0 is still there — the CI workflow, and the guard line in whichever pre-commit mechanism the project runs. It never scans history: a full scan costs tens of seconds and returns the same answer until somebody commits, so running it per hygiene call would end hygiene's use as a command you reach for casually. What decays is the wiring; that is what this reads, in milliseconds.

  Weighted as a warning worth five points, never a blocker. Blocker weight in this score model means the install is broken, and every project surveyed lacks a gate today — shipping it as a blocker would drop all of them twenty points at once and put every repository under the floor simultaneously, which stops the floor meaning anything. A project with no pre-commit mechanism is not marked down for the half it cannot have.

- **A failed assertion prints what it was looking at.** Previously it printed its own name and nothing else, which is fine when you can reproduce the failure and useless when you cannot. An intermittent CI failure is exactly the one that has to be diagnosable from the log alone, because by the time anyone looks the runner is gone — and that is precisely where the suite said least.

  A failure now prints every variable the expression named, and for an exit code the output that came with it: this suite pairs `FOO_EXIT` with `OUT_FOO` or `FOO_OUT` about half the time, and an exit code alone rarely says why. Output is capped at fifteen lines with a count of the rest. No call site changed.

- **`git-hygiene` gains an issue-references section.** `closes`, `fixes`, `resolves` and their variants close an issue on merge, and the parser reads the keyword and the number and nothing around them — not the sentence, and not the negation. Two issues closed by accident on one day: a subject reading `track entry-scan fix #120`, meaning the fix tracked as #120, and a body sentence reading "It does not fix #134's flake", which says the opposite of what happened. Both needed reopening with a comment explaining a decision nobody had made. Same treatment the Staging section got after being burned twice: written down rather than remembered.

### Fixed

- **CI blocked secrets being added; it no longer fails on history.** The workflow shipped in v1.54.0 scanned full history with `--exit-code 1`. Wiring the gate on ai-kit itself is what exposed the problem: eight findings, all in this kit's own scan fixture, all correctly demoted to low signal by the scanner — and the job would still have gone red on every push, forever.

  It generalises badly. Four of the six projects measured are dominated by that kind of false positive, so the emitted job would have been permanently red in most of them, blocking merges over something no commit in the pull request introduced. A job that is always red is one nobody reads. History is answered once, by a human reading the ranked report; what CI can usefully gate is what the event adds, so the job now resolves that range and scans only it. Verified three ways: full history exits 1 on ai-kit, the range exits 0, and a newly committed private key inside the range still exits 1.

- **The `test` workflow had been red on master for at least twelve commits, across four release tags.** Nobody looked, including during two releases cut that same day. Two unrelated causes, neither a platform divergence, though both looked like one because the suite is green on macOS.

  `docs-sync-repo-hygiene` asserted against a fixture git cannot carry: `.gitignore` holds a bare `.agents/`, which matches at any depth and swallows the fixture's copy too. Locally the directories were still on disk from a run months earlier, so five assertions passed against leftovers while a fresh checkout had nothing to assert against. Rebuilt at the top of the case, beside the `empty_dir` self-heal that already existed for the same reason.

  `release-install` had never run on a pull request at all. `install.sh` clones with `--branch master`, `actions/checkout` leaves a pull request on a detached HEAD, so the clone aborted at `rc=128` and the case reported zero assertions. The case that verifies the installer end to end had therefore verified nothing on every pull request it ever ran in.

- **`pipefail` no longer turns a SIGPIPEd writer into a failed assertion.** `recommend` and `structure` failed one CI run and passed a re-run of the identical commit. An assertion asks what the output contains, not whether the process that produced it survived writing — but `echo "$VAR" | grep -q x` makes grep exit on the first match and SIGPIPE the writer, and under `pipefail` that 141 became the pipeline's status. Whether it fired depended on payload size against the pipe buffer, so it surfaced as flakiness rather than a clean failure, which is the worst shape: a red run looks like bad luck and a green one proves nothing.

  Fixed in `assert()` rather than at the call sites. The suite has 262 such pipelines across 20 case files, and an earlier per-site fix left every other one standing. Suppressing pipefail must not suppress real failures, so the harness case asserts both directions.

- **Seven shellcheck warnings that were failing lint separately.** Four were `SC2046` on `$([ … ] && echo --no-prompt)`, which are deliberately unquoted and rely on word splitting to vanish when the flag is off — quoting them would have handed each section an empty argument instead of none, so they became an array with the `${arr[@]+…}` guard that keeps an empty array expandable under `set -u` on bash 3.2. Two were `SC2155`. One was a `case` arm that could never fire, since `*grep*` already matches `ripgrep` as a substring.

### Changed

- **ai-kit wired its own secrets gate.** Adding the hygiene section made the kit fail its own check, which is the honest signal that it was recommending something it had not adopted. CI only — there is no hooks path, no husky directory and no pre-commit hook here, so the emitter correctly wrote nothing rather than standing one up. This is also what caught the CI template bug above, before it reached six projects.

### Notes

One flake remains open and known: `doctor` exits non-zero intermittently on `ubuntu-latest`, and does not reproduce locally across fifteen runs. The diagnosability work above means the next occurrence should finally name what fired, rather than reporting that a number was wrong.

Tests: 1038 → 1067 passing.

## 1.54.0 — 2026-08-20

### Added

- **`/ai:secrets-scan` reports what is already in a repo's history.** The kit had no way to answer that question, and the thing it did carry pointed the wrong way: `hooks-patterns.json` recommended `gitleaks-scan` as a `PreToolUse` `Edit|Write` hook, which inspects only what an agent is about to write. A sweep across six real projects returned 104 findings and every one of them predated the sweep — the recipe would have caught nothing. It only ever produced a wrong hook because nobody approved it: `recommend-tools` generates the hook script from the recipe at approval time, so a wrong `event` yields a wrong hook faithfully. The recipe is dropped rather than corrected, since a write-guard for secrets duplicates `block-env-edits` for the common case and cannot see a commit. `block-env-edits` stays: it guards an action rather than a history, and its shape was right all along.

  Three properties carry the scanner. The report enters agent context, so it holds paths, line numbers, rule ids and entropy and never a value. Findings are ranked and never filtered — the rule that misfires on serialized blob data is exactly what surfaced database dumps committed to a real repository, so the tail collapses to a count line instead of being dropped. Findings group by file and sort by entropy, because those 104 findings were 25 files and the raw count was itself the noise. A named rule inside a test or example path is demoted: the test fixture proves the point, since its private key scores the highest entropy of anything present and still belongs below a Stripe key in `src/`.

  No baseline, ever. On a first run a baseline records the findings the scan exists to surface as already accepted, which is the one thing a discovery scan must not do.

  Exit codes separate three states a scanner must never conflate — `0` clean, `1` findings, `2` did not run. The third came out of review: gitleaks failing on a bad config was reporting "no findings" with exit `0`, handing back false assurance about secrets and ending the investigation. An absent binary still skips at `0` by design, per the tool-gate protocol; a binary that *errors* is a different state.

- **`apply-secrets-gate.sh` wires prevention, deliberately asymmetric.** CI is emitted unconditionally: one file, one shape, no detection, and the half `--no-verify` cannot walk past. `secrets-hygiene.mini.md` already prescribed that ordering and had nothing behind it.

  Pre-commit is appended only to a mechanism the project already runs, and a mechanism is never introduced. The six surveyed projects use four different ones — husky, a tracked hooks directory, plain `.git/hooks`, and nothing — and not one uses the `pre-commit` framework, so emitting its config would add a fifth mechanism plus a Python dependency to repositories that already have a working hook. That is the accumulation `/ai:dedupe` exists to catch, and shipping it from ai-kit itself would have been worse than shipping no guard.

  Review caught the boundary in the wrong place: a project with husky configured but no `pre-commit` file written yet was told it had no mechanism, and nothing was written. The mechanism plainly existed — the maintainer opted into it — and only the hook file was missing. Using an existing mechanism is not the same as introducing one, so a configured hooks path or a `.husky/` directory now counts and the hook file is created inside it. Only a project with neither still gets the print-the-command path.

  The emitted workflow installs a pinned gitleaks release rather than using the marketplace action, which requires a licence key for organisation accounts. A repository moving under an org would otherwise watch its security gate quietly become a no-op — the worst failure mode a guard like this has, because nothing announces it. CI runs with `--redact`: job logs are routinely readable by more people than the repository is.

### Fixed

- **The `gitleaks-scan` removal reformatted its whole catalog.** Editing the JSON through `json.dump(indent=2)` rewrote every compact inline array in `hooks-patterns.json`, moving twenty-five untouched recipes, pointing `git blame` on all of them at the commit that removed a different one, and burying the single meaningful change in a 158-line diff. The sibling catalogs all still use the compact form. Restored from the previous tag with only the removed block cut out; the diff against `v1.53.1` is now nine deletions and nothing else.

### Notes

Both features were built by `/ai:autonomous` from Agent Briefs, and the review step caught a blocker in each — a failed scan reporting "no findings", and a husky project told it had no mechanism. Two for two is worth recording: the agent-writes/human-reviews split is doing real work here, not ceremony.

Tests: 1002 → 1038 passing.

## 1.53.1 — 2026-08-20

### Fixed

- **doctor did not check the directories ai-kit emits into.** Its project block walked `.claude/skills`, `.agents/skills` and `.cursor/skills` and stopped there, while `emit-rules.sh` writes `.claude/rules/` and `.cursor/rules/` — so the one thing ai-kit puts in a project unprompted was the one thing the diagnostic never looked at. Laravel Boost moved its layout from `.ai/` to `.agents/` in a project here and took the old directory with it; 19 symlinks across `.claude/`, `.cursor/` and `.junie/` were left pointing at the hole and `/ai:hygiene` reported 9. Among the ten it missed were the rules links `global.md`, `engineering.md` and `claude-mem-context.md`, which stopped loading into agent context without saying anything. Both rules directories are now in the same loop. Absence is not a finding there: a `--no-rules` project has no rules directory to check.

- **The broken-symlink message sent the diagnosis the wrong way.** It read *"N broken symlinks (ai-kit moved? run bootstrap-project.sh)"* and was wrong on both halves. ai-kit had not moved — another tool changed its own layout — and `bootstrap-project.sh` links `*/skills`, `*/agents` and `*/commands` and never touches `*/rules`, so anyone following the advice would have been left with ten dead links and the impression they were repaired. Each dead link now prints on its own line with the target it lost and a remedy that fits the case: `ln -sfn` at a same-named file that survived elsewhere in the project, `rm -f` when nothing did. `ln -sfn` rather than `rm` + `ln` because `rm` is aliased interactive on many macs, where a pasted recipe stalls on a prompt nobody sees.

  Dead links in agent directories ai-kit does not own — `.junie/` is Boost's — are reported too, as a warning rather than an error. They still cost the agent whatever the target held, but repairing them is the owning tool's call.

- **`verify-setup.sh` failed a project on the language of a heading.** The skills/lifecycle check grepped for `Agent skills` or `Agile lifecycle`, so a Dutch `CLAUDE.md` that documented the lifecycle phases and the skills in full, under "Werkwijze en skills", stuck on 18/19 in `--strict`. The only way to green was to rewrite the documentation to suit the grep, in a repo whose language rule says the docs are Dutch. The pattern now also accepts a skills directory path — an identifier survives translation, a heading does not. Both original headings stay in it, so docs that describe the skills without naming a path keep passing. A bare `/ai:` command mention is deliberately not a match: it would pass any document that names a command in passing, turning a check about whether the setup is documented into a check for one string. It deliberately does not read `branches.lifecycle` from `.ai-kit-setup` either: that field records the phase the project is in, not whether its docs say anything, and a check about a document should read the document.

Tests: 981 → 1002 passing. A new case, `doctor-broken-symlinks`, builds a project with a dead link in a skills directory, in both rules directories and in `.junie/`, and asserts the scope, the per-link detail, both remedies and the warn-not-error split; `lifecycle` gains a `verify-setup-language` section covering the Dutch doc, a doc that documents neither, a doc that only mentions an `/ai:` command in passing, and the English template.

## 1.53.0 — 2026-08-20

### Added

- **`git-hygiene` gains a Staging section.** Stage by path, never `git commit -a` or `-am`, and read `git diff --staged` before committing. This came out of two commits on one day that each carried a second, unmentioned change: `-a` sweeps every modified tracked file, and in a repo where more than one agent session is open that is the normal state rather than an edge case. The commit message then describes one change while the commit carries two, and nobody notices until someone reads the history back. Two checklist items enforce it. The rule is already universal and always-on, so this applies everywhere without new wiring, and the rule count stays at 34.

- **Review before release, written down.** `CLAUDE.md` and `AGENTS.md` now say to run `/ai:review` before a release rather than after. The doctor warns about a single committer in this repo and asks for a documented reviewer cadence; a weekly human sweep is not going to happen in a solo project, and a rule nobody keeps teaches the next session that rules here are optional. A reviewer starting from the diff is a real second pass.

### Fixed

- **`AGENTS.md` was never tracked.** Three scripts expect it and `context-lean` already reads it, so its absence from git was an accident rather than a decision. It mirrors `CLAUDE.md` exactly.
- **`.codex/` joins `.agents/` and `.claude/skills/` in `.gitignore`** — per-machine agent configuration, not project content.

## 1.52.0 — 2026-08-20

### Changed

- **`/ai:should-i-use` now refuses a verdict it cannot ground in your repo.** Two days of running the skill on real candidates exposed six ways a wrong answer got through, and the largest was structural: the skill spent fifty lines assessing the candidate and four lines on "read the repo", so a complete six-part verdict could be produced without a single fact from the project it was about. Project fit is now the first step rather than a note beside the verdict, and it carries a rule: **no verdict without a path or a count from this project.** Four questions run in order and stop at the first one that cannot be answered: where does it hurt here, where would it fire (paths and counts, never categories), who would run it, and what does it cost here. "Added value" must now restate that evidence instead of accepting the candidate's own marketing.

  The other five, each traced to a real failure. Fetching a README from `main` assessed a version nobody installs, because the repo's default branch was a working branch and `main` trailed it by a release: the input step now resolves the default branch, pins the HEAD SHA, and diffs any local install against it. Overlap was checked by name only, so a tool already inside the project under a different name read as new: it is now checked by derivation, by grepping the candidate's distinctive word lists, examples and rule numbering against the repo. Scope was absent although it decided two verdicts here, so a table now separates value that hangs on the repo, on the person, and on a task that ends. Licence was one noun in "what it is", and now says to follow the chain past the `LICENSE` file, because packaged work carries terms the wrapper does not restate. A candidate that delegated half its job to a companion was judged as a whole thing, so the skill asks for the missing half first.

- **A verdict is now recorded, not just spoken.** A new section says to write it where the project keeps decisions, with the reason next to an Ignore rather than the verdict alone: "we looked at this and said no" is worth nothing six months on, while "this is the same material as X, already in two of our files" stops the next person re-adopting it. In ai-kit that means `standards/external/VETTING.md` for adoptions and `standards/external/plugins-excluded.json` for Ignores. In a project with no such place the skill says so and proposes one instead of inventing a file nobody will read.

  Two eval fixtures cover the new behaviour: a synthetic candidate that trips all six failures at once, and an evidence expect added to the existing one.

## 1.51.0 — 2026-08-20

### Added

- **`docs-diataxis` rule** (on-demand) — pick the document mode before writing. Two questions place a document in one of four modes: tutorial teaches by building, how-to solves a problem for someone competent, reference describes and nothing else, explanation gives the why and is the only mode where opinion belongs. The rule then forbids mixing them: no reference table inside a tutorial, no hand-holding inside reference, no argument inside a how-to. Split and link instead. It covers structure only and points at `writing-style.mini.md` for sentence-level style and `/ai:copywriter` for the full editor. Adapted from [Diátaxis](https://diataxis.fr) by Daniele Procida. Rules 33 → 34.

  This is the one layer that survived a review of two writing skills offered for adoption. Both are now recorded in `plugins-excluded.json` as Ignore, with the derivation written down so the next session does not rediscover it. `technical-writing` stacks four layers, three of which restate `writing-style` and the 39 copywriter patterns down to the same examples; it also delegates its slop catalogue to a skill ai-kit does not have. `unslop` is Ignored for a stronger reason: it was already inside ai-kit twice. Its patterns 1 to 25 share the Wikipedia lineage of copywriter §1-33, and its 14, 26, 27, 28, 30 and 31 are the source of `writing-style` rules 1 to 6 and of copywriter §34-39, down to the same jargon list and the same plain-word list.

### Fixed

- **Patterns 34 to 39 shipped undocumented in v1.50.0.** A parallel session added six ai-kit-original plain-speech patterns to `/ai:copywriter` (colon connectors, abstract metaphor nouns, feeling words in place of a mechanism, dense sentences, adverbs propping up weak verbs, fancy synonyms) with the provenance table split correctly between the CC BY-SA §1-33 set and the MIT additions. They were in the working tree when the release commit staged the whole file. The v1.50.0 changelog entry now covers them.

- **`writing-style` credits its source.** Its jargon list (substrate, wedge, north star, flywheel) and plain-word list (utilize, facilitate, numerous) come from the `unslop` skill, and the lineage runs back to Wikipedia's Signs of AI writing. The rule landed without any of that. It also lost a correct count to a wrong correction: "39-pattern editor" was changed to 33 on the assumption it confused patterns with skills, when the skill did have 39 by then. Both restored.

- **The Dutch landing eval fixture carried a transcription error.** It presented `01 — Waarom Emeq Hub` as copy from a real page and asserted the audit catches em dashes in the section eyebrows. The page uses a middot, and every em dash in those components sits in a code comment. The fixture now uses the middot and asserts that a middot must not be flagged as an em dash. Em-dash coverage moved to the synthetic `dutch-tells.md` prompt, which can carry one honestly.

## 1.50.0 — 2026-08-19

### Added

- **`copy-nl` rule** (on-demand) — the Dutch half of the humanizer. `/ai:copywriter`'s 33 patterns come from English Wikipedia: the method transfers to Dutch, the word lists do not. About 30 Dutch tells across vocabulary (daarnaast, bovendien, middels, naadloos), constructions (naamwoordstijl, "niet alleen X maar ook Y", "of het nu gaat om"), openers and closers ("In de wereld van", "Kortom"), and punctuation, each mapped onto the English section number so a finding reads the same in either language. Scope is deliberately narrow: language facts only. Register (je/u), brand-banned words and tone are positioning choices, and a rule that decided them would impose one register on every repo. Those live in the project's copy-context instead. Rules 31 → 33.

- **Six new humanizer patterns in `/ai:copywriter`** (§34-39) — plain-speech checks that catch text which passes all 33 Wikipedia-derived patterns and still reads machine-written: colons used as mid-sentence connectors, abstract metaphor nouns (substrate, wedge, flywheel), feeling words standing in for a mechanism, dense sentences, adverbs propping up weak verbs, and fancy synonyms for plain words. These are ai-kit originals under MIT; the CC BY-SA 4.0 carve-out stays scoped to §1-33, and the provenance table in `SKILL.md` records the split. The same six back `writing-style` rules 1 to 6, deliberately: the rule is the always-on floor, the skill is the full editor.

- **`writing-style` rule** (always-on, universal) — a prose floor for everything the agent emits, not only text a user asks it to write: commit bodies, PR descriptions, issue text, docs, release notes. No em dashes, plain word over jargon noun, name the mechanism rather than the feeling, cut the adverb or give the number. It scopes itself against caveman ("compression modes set their own register; this rule still governs word choice"), so the two compose rather than fight.

- **`/ai:copywriter` now reads project context.** A new ai-kit-owned block, marked as such and separate from the vendored body, teaches the skill to read `.agents/memory/project/copy-context.md` before its intake and skip every question that file already answers. After a full intake it offers to persist the answers, writing both the memory file and its `MEMORY.md` index line, and creating the memory tree when the project has none. It never writes either file unasked. Dutch is judged from the text in front of it rather than from project configuration, so `copy-nl` also loads on a first run where no copy-context exists yet; `detect-tooling.sh` emits no language axis, so there is nothing to detect against.

  Proven on a real repo before shipping. A cold intake against emeq-hub's landing page produced a copy-context whose value was mostly in what it refused: asked twice to invent a build-time number and customer quotes, the skill declined both, and the detour produced better material than the invention would have. The number came out of git instead (23 working days for one connector, measured across 1040 commits, with the caveat that the window includes maintenance), and the customer voice was replaced by founder voice sourced from artefacts the repo already contained. The intake also surfaced two claims on the live site with no coverage behind them.

- **New eval fixture** `copywriter/dutch-tells.md` asserts the Dutch path end to end: that `copy-nl` loads unprompted, that specific tells are caught and mapped to a section number, and that the skill declines to decide je/u.

### Fixed

- **Count guard missed the Cursor manifest.** `workflow/.cursor-plugin/plugin.json` carries a skill count in its description that no surface in `bin/count-primitives.sh` was watching, so it drifted silently while every tracked surface stayed correct. Now tracked for both skills and commands.

## 1.49.0 — 2026-08-19

### Added

- **`/ai:copywriter` skill** (vendored) — a reader-first copywriter plus a humanizer, in one skill. The copywriter side interviews for the ICP, the category and the story before writing, then delivers variants across angles for headlines, short descriptions, microcopy, error messages, empty states, subject lines, LinkedIn posts and strategic blog posts, and picks one with the reason tied to the reader's feeling. The humanizer side detects and fixes 33 AI-writing patterns (promotional language, false ranges, rule of three, negative parallelisms, em dash overuse, copula avoidance, and the rest). It refuses to invent product facts: when the strongest line needs a number or a partner name, it asks instead of filling the gap. Skills 38 → 39.

  Vendored from [mikiarlo3/ai-copywriter](https://github.com/mikiarlo3/ai-copywriter) at `08b53b1a`, not recommended as an external install, because ai-kit will extend it: the 33 patterns derive from **English** Wikipedia, so Dutch AI-tells ("daarnaast", "bovendien", "het is belangrijk om te vermelden") are not covered yet. A native NL pattern layer and a per-project copy-context are the planned follow-ups. For the same reason it is **not** in `plugins.json` — vendoring and recommending the upstream install would double-bundle.

  **Licence carve-out.** This one file is not covered by ai-kit's repo-wide MIT. The humanizer patterns come from [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) (CC BY-SA 4.0) via [blader/humanizer](https://github.com/blader/humanizer) (MIT, © 2025 Siqi Chen) and mikiarlo3/ai-copywriter (MIT, © 2026 Mickey Haslavsky). The attribution block at the foot of `SKILL.md` must travel with any copy. The rest of ai-kit stays MIT.

  Vetted against all eight `VETTING.md` criteria before landing. Two findings worth carrying forward: upstream's default branch is an agent working branch (`claude/humanizer-copywriting-skill-u5x4vd`) with `main` trailing it by a release, so the SHA is pinned rather than the branch; and a skillspector static scan returned five findings that were **all five false positives**, matching example prose and MIT warranty boilerplate rather than instructions. That last one is evidence against wiring skillspector's static mode as a CI gate over ai-kit's own Markdown skills.

### Fixed

- **Count guard missed the Cursor manifest.** `workflow/.cursor-plugin/plugin.json` carries a skill count in its description, but no surface in `bin/count-primitives.sh` was watching it, so it silently drifted while every tracked surface stayed correct. Now tracked for both skills and commands.

## 1.48.0 — 2026-07-11

### Added

- **`pre-write-discipline` rule** (universal, always-on) — four gates before the first `Edit`/`Write` of any change ≥ 10 LOC or new file: state assumptions, minimum diff, surgical scope, verifiable goal. Plus the anti-patterns each gate blocks (speculative flags, single-implementation abstractions, error handling for impossible states, drive-by "improvements", comments restating the code) and a trivial-task escape hatch. ai-kit has run these four rules in its **own** `CLAUDE.md` since the first release and never shipped them: the rules catalog covered how an agent should *read* (`context-discipline`) but not how it should *write*. Downstream `/ai:setup` projects now get both. Adapted from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (Karpathy's observations on LLM coding pitfalls); rules 30 → 31.

## 1.47.1 — 2026-07-11

### Fixed

- **`graph-fresh` misread `built_at_commit`.** graphify only rewrites `graph.json` when the AST topology actually moves, and strips `built_at_commit` before that comparison (`watch.py`). The stamp means *"the commit at which graph content last changed"*, not *"the commit the graph has seen"*. v1.47.0 read it as the latter, so a commit touching only config, docs, or comments warned forever — and the `graphify update .` it recommended could never clear the warning. Git drift is now treated as a **candidate, not proof**: on a TTY the check offers to run the free `graphify update .`, and if graphify reports no topology change the graph already matched the code — that HEAD is recorded in `graphify-out/.ai-kit-graph-verified` so it stops nagging. Under `--no-prompt` / CI it stays strictly report-only.
- **`companions.json` pointed graphify at a repo that does not exist** (`github.com/yusufkaracaburun/graphify`). The real upstream is [`Graphify-Labs/graphify`](https://github.com/Graphify-Labs/graphify) (MIT); the PyPI package is `graphifyy` (double y) while the `graphify` name is being reclaimed upstream. A false provenance claim in our own catalog is exactly the marketing-parity failure `VETTING.md` exists to catch.
- **`post_install_command` recommended a paid command.** It was a full `graphify .`, which runs the LLM extractor and costs real money ($0.05 on a mid-size repo). The routine refresh is `graphify update .` — AST-only and free.

## 1.47.0 — 2026-07-11

### Added

- **`/ai:docs-sync` → `graph-fresh`** — detects a stale graphify knowledge graph. graphify stamps `built_at_commit` into `graphify-out/graph.json`; ai-kit now compares it to `HEAD` and counts the files changed since (excluding `graphify-out/` itself). A stale graph is worse than no graph: `CLAUDE.md` and the search-delegation hook both route the agent to `graphify query` instead of grep, so it answers from a map of code that has already moved. Warns on drift, on an unreachable `built_at_commit` (rebased/squashed away), and on a graph with no stamp. Skips silently when there is no `graphify-out/` or the project is not a git repo. Report-only — never runs `graphify update` for you. New: `bin/ai-kit-docs-sync-graph-fresh.sh`, `--skip-graph-fresh`, 21 test assertions.

### Changed

- **`standards/external/plugins-excluded.json`** — `openwiki` (langchain-ai/openwiki) recorded as **Ignore**. Ignored on category, not trust: its code mode duplicates graphify (and is a strict downgrade — LLM-written prose bakes hallucination to disk where graphify is AST-derived, deterministic and free), its personal mode duplicates llm-wiki. Its one genuinely reusable idea — anchoring a generated artifact to a git head so staleness is computable — needed no adoption; it shipped as `graph-fresh` above.

## 1.46.0 — 2026-07-11

Context-budget release. The theme: ai-kit already *said* the right things about context discipline, in a universal always-on rule — and the agent skipped them under pressure, because a rule is prose. This moves the load-bearing parts into layers the model cannot skip, and corrects a piece of guidance that was actively teaching the expensive habit.

### Added

- **`search-delegation-check.sh` hook (Tier A, auto-wired).** `PreToolUse(Bash|Grep|Glob)` — fires **only on repo-wide sweeps** (a Bash `grep`/`rg`/`find`, or a `Grep`/`Glob` with no `path` to narrow it) and points the agent at the cheaper route: `graphify query` when `graphify-out/graph.json` exists, otherwise a sub-agent (`Explore`, `ai:explore`, `cavecrew-investigator`) so the raw output lands in the sub-agent's context instead of the main one. A `Grep` already scoped to a directory stays silent — without that distinction the nudge would fire on all 20-30 `Grep` calls in a session and cost more context than it saves. New setup Branch 2d; applied without asking (ai-kit's own primitive, advisory `additionalContext` only, blast radius stops at the project). Applier: `bin/apply-search-delegation-hook.sh`, which **replaces** the older graphify-only nudge rather than stacking a second hook beside it.
- **caveman as a universal companion (Tier A, auto-prompted).** New setup Branch 2e, cloned from the Branch 2c universal-MCP pattern: catalog-driven, prompt-per-candidate, outcome recorded in the marker, never re-asked. `bin/apply-caveman.sh` adds the marketplace, installs the plugin via the official `claude plugin` CLI, and writes caveman's own `defaultMode` so the mode is explicit instead of resting on its built-in fallback. Supports `--status`, `--dedupe-only`, `--uninstall`, `--mode`.
- **Duplicate-hook guard for caveman.** caveman's standalone installer (`bin/install.js --with-hooks`) copies its hooks into `~/.claude/hooks/` **and** writes them into `~/.claude/settings.json` — but the plugin manifest already declares the same `SessionStart` + `UserPromptSubmit` hooks. A machine that ran both fires every caveman hook twice per event. `apply-caveman.sh` detects this and strips the standalone copies (backing settings.json up first), leaving the plugin manifest as the single source. It refuses to strip when the plugin is *not* enabled, since that would disable caveman outright.
- Marker fields `branches.universal_companions_prompted` (accumulating, union-merged like `universal_mcps_prompted`) and `branches.search_delegation_hook`.

### Changed

- **`context-discipline` now distinguishes three ways to shrink context, not one.** The old "Stop and hand off" bullet pointed at `/ai:checkpoint` → `/clear` for every situation, which taught the most expensive cycle available as the default. Now: `/compact` mid-task (the default), checkpoint→clear→resume only when the context is *polluted* with junk a summary would carry forward, and a full checkpoint only at a real break (session end, pause, topic switch). The "delegate wide exploration" bullet names the sub-agents that actually exist and clarifies that a scoped `grep` is fine — the rule is about sweeps.
- **caveman doctrine: "never a default" → "never *silent*".** Five places said caveman must never be enabled by default. It is now auto-prompted with default yes, and every offer states the machine-wide blast radius: activation changes the agent's output style in *every* repo on the machine, not just the target. ai-kit still vendors nothing — the plugin installs from its own marketplace via the official CLI.
- `README.md`, `docs/mental-model.md`, `docs/diagrams.md` updated for both.

### Fixed

- **`/ai:checkpoint --mid-session` no longer claims to do something it does not.** Its description promised "compact in place without `/clear`", but the flag only writes a memo — the context does not shrink. A user who read that and kept working sat in a context that never got smaller. The flag now says so plainly and points at `/compact`, which is what actually frees context.
- `standards/external/companions.json` pointed caveman's upstream at `yusufkaracaburun/caveman`; the real marketplace is `JuliusBrussee/caveman` (which the glue template already had right).

### Removed

- `context/templates/companions/graphify-hook.json`. The search-delegation hook supersedes it — one hook that switches message on graphify's presence, instead of two overlapping ones.

## 1.45.0 — 2026-07-10

### Added
- `test-suite-stop-gate` hook recipe in `standards/external/hooks-patterns.json` — Stop-event gate that blocks turn end while the project test suite fails; failures feed back (exit 2 + stderr) so the agent fixes before finishing. Recipe mandates a `stop_hook_active` loop-guard, clean-tree skip, a green-hash cache so an unchanged tree never re-runs the suite, and a measured-runtime bar (~60s) before wiring. Complements the per-edit `jest/pytest/vitest-related` hooks with a turn-level green gate.

## 1.44.1 — 2026-07-10

### Fixed

- **context-lean no longer warns on Boost-managed files.** Laravel Boost writes `AGENTS.md` as one wholesale `<laravel-boost-guidelines>` block — not user-curatable, so a size warning there is a permanent false positive (−5 on every hygiene run) that can only be silenced by disabling Boost. The check now detects the Boost wrapper on line 1 and emits a note instead of a warning; files with user content above a Boost block still warn. Found in the field on emeq-hub within an hour of the v1.44.0 release.

### Notes

Suite: 929 passed / 0 failed (+2 new asserts).

## 1.44.0 — 2026-07-10

### Added

- **`/ai:hygiene` section 6: context-lean.** Root `CLAUDE.md` / `AGENTS.md` load at the start of every session — a fixed token tax before the first prompt, and past ~200 lines they reduce adherence rather than help. The new `ai-kit-context-lean.sh` warns (−5 score) when either file exceeds 200 lines and prescribes the curation fix: directory-specific notes → `<subdir>/CLAUDE.md`, stack conventions → path-scoped rules, multi-step procedures → a skill. Skips silently when neither file exists. Opt out per run with `--skip-context-lean`.
- **`context-discipline` rule: always-loaded files bullet.** Curation beats compression — content moved out of the always-loaded path costs zero tokens per session, while compressing it in place still pays the tax every start.

### Notes

Pattern adopted from a community article on the CLAUDE.md context tax, assessed via `/ai:should-i-use` (verdict: adopt as pattern, narrow slice). Suite: 927 passed / 0 failed (+15 new).

## 1.43.2 — 2026-07-09

### Added

- **`docs/diagrams.md`** — mermaid views of the kit: a wiring diagram (source → distribution → host, per primitive) and a runtime diagram (one turn: skill routing, subagent delegation vs. Cursor's inline fallback, `PreToolUse`/`PostToolUse` hook events). `docs/architecture.md` now points at it instead of carrying a second, drift-prone ASCII copy.

### Fixed

- **Primitive-count guard (#90) had holes.** `count-primitives.sh --check` verified README's rule and command counts but never its skill count, and matched none of its table cells. README had advertised 27 skills and 8 slash commands since v1.12.0 with CI green; the real numbers are 38 and 11. Added patterns for the table cells, the prose skill count, and `docs/diagrams.md`.
- **`count-primitives.sh` stale-match hint mis-parsed its own patterns.** The pattern was fed to `grep -nE` without escaping, so a literal `|` read as alternation and `(SKILL.md)` as a capture group. Escape ERE metacharacters before placeholder substitution.
- **`tests/bin/run-all.sh` ignored `JOBS`.** It set the variable, printed it in the summary, and launched all 36 cases at once. The 500ms wall-clock assertion in `docs-sync-nudge` failed under contention the runner itself created, and `--serial` was a no-op (157s vs 156s, identical failure). Fan-out is now throttled on `jobs -pr`, portable to bash 3.2.
- **`run-all.sh` under-counted passes on failing cases.** It matched `PASS: N` only, so a case ending in `FAIL: 1 passed: 22` reported `pass=0`.
- **`docs-sync-repo-hygiene` fixture could not survive a clean checkout.** It depends on an empty directory — untrackable by git, and deleted by the test's own confirm-fix path. The case now creates it during setup.

### Notes

Patch release: documentation, count-guard coverage, and test-harness correctness. No skill, scorer, or schema change. The full suite now reports 912 passed / 0 failed; before this cut it was 847 passed / 4 failed on master.

## 1.43.1 — 2026-06-23

### Changed

- **`plugins-excluded.json` +1: `codebase-memory-mcp`** (DeusData/codebase-memory-mcp, MIT). should-i-use verdict **Ignore**: a tree-sitter + Hybrid-LSP code-intelligence MCP that is an *alternative* to graphify (ai-kit's knowledge-graph/input companion), not complementary — its own README calls itself "similar in spirit to graphify's graphify-out/". Two knowledge-graph tools = double-bundle noise; also runs against ADR-0006 (ai-kit deliberately dropped MCP, stays pure Bash+Markdown). Whether it should *replace* graphify is a deliberate spike, not a catalog add — tracked in #109.

### Notes

Patch release: marketplace was stranded at v1.40.0 (3 releases behind); this cut captures the untagged `codebase-memory-mcp` ledger commit so the marketplace can advance to a tag that includes all of master. Data-only (catalog ledger); no scorer/skill/schema change.

## 1.43.0 — 2026-06-22

### Added

- **`recommend-tools` surfaces deliberate exclusions** — new Phase 2b reads `standards/external/plugins-excluded.json` and lists every excluded tool (name + one-line reason) as a "considered, not adopted" curation boundary. Closes the gap where the ecosystem audit's `KEEP-EXTERNAL` path only fired for *already-installed* tools, so a fresh project never learned what ai-kit deliberately rejected. `/ai:setup` Branch 14 points at the behavior; surfaced in the recommend-tools output contract.

### Changed

- **`plugins-excluded.json` +1: `designlang`** (Manavarya09/design-extract). should-i-use verdict **Ignore**: a live-DOM design-system *extraction* tool that ships an MCP server (structurally mcp-bucket-eligible) but optimizes none of the companion catalog's AI-loop dimensions, fails the promotion-quorum bar (single-maintainer, v12.x high-churn, sponsor-affiliate README → preview-only), and is one-shot task tooling, not durable per-project infra. Same out-of-scope bucket as `taste-skill`. Direct-install pointer kept in the entry's `alternative`.

### Notes

LEAN: catalog data + SKILL.md prose only; no scorer/script/schema change. `audit-setup-symmetry` green; standards mirror identical.

## 1.42.0 — 2026-06-14

### Added

- **shadcn MCP recommendation** (closes #102) — `standards/external/mcp-servers.json` gains a `shadcn` entry keyed on the existing `shadcn` framework signal (a `components.json` with the shadcn schema). `/ai:recommend-tools` now surfaces it for any shadcn project with install paths (`npx shadcn@latest mcp init --client claude` for project scope; `claude mcp add --scope user shadcn -- npx shadcn@latest mcp` for monorepos) + scope guidance (one components.json → project, several → user). Commands verified against shadcn docs.
- **`pre-write-gate` hook recipe** (closes #101) — `standards/external/hooks-patterns.json` gains a universal `PreToolUse` (Edit|Write|MultiEdit) hook recommendation that surfaces the 4-principle pre-write checklist (assumptions · minimum · surgical · verifiable) as non-blocking context before edits. Closes the gap where auto-loaded CLAUDE.md rules are present but never gated at edit time — an enforcement layer that holds regardless of which skill is active. Opt-in via `/ai:recommend-tools` (ai-kit recommends, never auto-wires).

### Changed

- **`/ai:checkpoint` housekeeping** (closes #103) — the end-of-checkpoint hygiene/docs-sync nudge becomes an inline run. Default is **report-only**: it runs `/ai:hygiene` + `/ai:docs-sync` (same applicability gates), embeds a `## Housekeeping` section (score + per-check summary + Applied/Needs-approval split) in the memo, and mutates nothing. `--also-housekeeping` additionally auto-applies the safe idempotent fixes (MEMORY.md dead-links, empty-dir rmdir, finished-work branch cleanup); risky items are never auto-applied. `--skip-housekeeping` falls back to the old cheap nudge. (Default kept non-mutating by design — a memo command should not change branches/files unprompted.)

### Docs

- Cite Addy Osmani's *Loop Engineering* as external validation in `docs/spikes/aikit-autonomous-ralph.md` (closes #107) — new `## External validation` section maps the essay's six primitives 1:1 onto ai-kit/CC-harness surfaces and ties its "comprehension debt / cognitive surrender" framing to the spike's trust model.

### Notes

LEAN: #101/#102 are catalog data only (no scorer code); #103/#107 are SKILL.md / doc prose. Regression asserts added for shadcn (#102) and pre-write-gate (#101). Full suite 912 passed / 0 failed.

## 1.41.2 — 2026-06-14

### Fixed

- ai-kit's own `/ai:docs-sync` now reports **0 dead links** on the repo (was 28). Root causes, all fixed:
  - **5 real cross-reference bugs** in canonical skills — `grill-me`, `improve-codebase-architecture`, `setup` linked siblings as `../ai:<skill>/SKILL.md`, but the directories are `<skill>` (no `ai:` prefix). Stripped the prefix; all targets resolve.
  - **Dead-link checker matched links inside inline code spans** — link-syntax examples written as inline code (in CHANGELOG, the docs-sync/commands SKILLs) were flagged as navigable. Now a link is skipped only when the whole match sits inside a backtick span; a link whose *label* is inline-code stays checked (`bin/ai-kit-docs-sync-dead-links.sh`).
  - **`.docs-sync-ignore` path-prefix entries were broken** (`bin/lib/docs-sync-excludes.sh`): the `${line#**/}` glob collapsed `tests/fixtures` → basename `fixtures` (would prune canonical `standards/`), and `awk -v` choked on the newline-joined prefix list (silently dropped every file). Both fixed — `**/` strip now guarded to literal prefixes; prefix filter rewritten in pure bash.
- Added repo `.docs-sync-ignore` excluding non-authored / duplicate trees from ai-kit's self-scan: `.agents/` (third-party installed skills), `tests/fixtures/` (intentional broken links), the synced `workflow/standards` + `workflow/context` mirrors (canonical copies are scanned), and the frozen `docs/roadmap-archive.md`.
- Regression: inline-code-span fixture + assert in the docs-sync test. Full suite 910 passed / 0 failed.

## 1.41.1 — 2026-06-14

### Fixed

- `emit-rules.sh` no longer emits dead cross-reference links (closes #105). "See also" links in `standards/rules/*.mini.md` used `.mini.md`/`.nano.md` suffixes and `../` depths that 404 in the flat emitted layout (`.claude/rules/<name>.md`, `.cursor/rules/<name>.mdc`) — 27 broken links that ai-kit's own `/ai:docs-sync` flagged. New `_emitter_body` (shared lib) rewrites each link against the set of rules actually emitted this run (`$AIKIT_EMITTED_RULES`): a link to an emitted rule → flat `./<name>.<ext>` sibling (ext-aware: `md` for Claude Code, `mdc` for Cursor), filename-style labels de-suffixed; everything else (non-emitted rule, skill, external doc) → unlinked, label text kept. Emitted output now passes the dead-link check (0 broken). Regression: 3 asserts in `tests/bin/cases/bootstrap-emit.sh`.

## 1.41.0 — 2026-06-14

### Added

- `recommend-tools` plugin catalog: `ui-ux-pro-max` (`standards/external/plugins.json`, category `design`) — surfaced for frontend stacks alongside `frontend-design` / `lazyweb`. Genuinely additive: priority-ranked, `--domain`-queryable design-rule database + shadcn MCP (structured token/pattern output, not just critique). Marketplace-clean (`/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`); single-source → surfaced, never default-recommended.

### Changed

- Decision-ledger discipline: `/ai:should-i-use` Ignore verdicts on catalog-eligible tools are now recorded in `standards/external/plugins-excluded.json` instead of evaporating into chat. First entry: `taste-skill` (Leonxlnx/taste-skill) — Ignore (overlaps existing design entries + ui-ux-pro-max; `npx skills add` install doesn't fit the plugin schema; motion/image-board *generation* is out of scope for durable per-project infra).

### Notes

LEAN scope: data-only — two `standards/external/*.json` entries + plugin-copy sync (`bin/sync-plugin-standards.sh`). No scorer/skill code touched. uupm cleared a VETTING.md parity pass with one caveat recorded in its catalog `value`: upstream count claims drift across its own manifests (styles 50+/67, stacks 10/15; README "161 reasoning rules" vs manifest "161 palettes") — capability verified on disk, specific counts treated as advisory.

## 1.40.0 — 2026-05-29

### Added

- `/ai:exploratory-test` skill (closes #97) — captures a long human-driven UI/UX manual review session and bundles findings into one clean parent GH issue per scope. Tester emits 50-100+ free-form findings across roles/apps/pages; skill acks each with one short line (`#N [scope] <one-line>. Gelogd.`), tracks scope-shifts silently, and on end-trigger (`klaar` / `bundel naar github` / EN equivalents) normalizes into an overview table + per-finding repro/expected/actual + cross-references cluster + open-questions section, then creates one parent issue per scope via `gh issue create`. Defaults: capture-only (no diagnose during flow), free-form (no strict template), per-scope bundling (new host → new parent), NL acks (with `--lang en` flag for English). Hands off to `/ai:triage` or `/ai:to-issues` for phase-2. Sibling to `/ai:review` (static-code review) but for human-driven UI/UX review.
- Eval fixture: `tests/eval/prompts/exploratory-test/multi-role-bundle.md` — multi-role / multi-host capture scenario with 9 expectations covering ack format, scope-tracking, label detection, parent-per-scope, body structure, and phase-2 hand-off.

### Notes

LEAN scope: SKILL.md + eval fixture only. No new bin/helpers — the skill is conversational, not deterministic. Defaults come from a proven manual run (naschool#81 / naschool#82, 2026-05-28, 89 findings across 4 roles on 2 hosts). Skill count: 37 → 38.

## 1.39.0 — 2026-05-29

### Added

- Self-host PaaS advisory (closes #20) — Coolify-only v1:
  - `bin/detect-tooling.sh` emits new `deploy` block: `shape` (`serverless` / `self-host` / `mixed` / `unknown`), `serverless_markers`, `self_host_markers`, `coolify_detected`. Serverless markers: `vercel.json`, `netlify.toml`, `wrangler.{toml,jsonc,json}`, `serverless.{yml,yaml}`, SAM templates. Self-host markers: `Dockerfile` + compose pair, or any `.coolify/` / `coolify.{json,yml,yaml}` marker.
  - New catalog `standards/external/paas.json` — Coolify entry (AGPL-3.0, UI-driven, single-host or multi-server). Trade-offs vs Dokku/Caprover/Kamal documented inline. Dokku, Caprover, Kamal deferred to follow-up issues — catalog grows from real adoption signal, not speculation.
  - `bin/recommend-tools.sh` gains `--kind paas`; scorer (`bin/lib/recommend-tools-lib.sh`) honours new `deploy_shape` + `env` signal types.
  - Companion MCP recommendation: Coolify MCP server entry added to `mcp-servers.json` (gated on the same `deploy_shape=self-host` + marker + `COOLIFY_*` env signals). Second-order: pick PaaS first, then optionally wire MCP.
  - `recommend-tools/SKILL.md` + `setup/SKILL.md` Branch 14 wire the new surface; preview-then-confirm trust model — ai-kit never writes Docker/server config without explicit approval.
- Tests: 10 new asserts across `tests/bin/cases/detect.sh` (deploy_shape detection across 5 fixtures + JSON surface) and `tests/bin/cases/recommend.sh` (PaaS scoring on self-host / serverless / `.coolify` marker / `COOLIFY_API_KEY` env). `audit-setup-symmetry.sh` validates paas.json wiring path automatically (no edit needed — generic catalog detection).

### Notes

LEAN scope: Coolify only. Dokku/Caprover/Kamal deferred per the principle that the catalog should grow from validated adoption (the user runs Coolify in production via naschool, hence v1). The `env` signal type added to the scorer is generic — usable by any future catalog entry.

## 1.38.0 — 2026-05-29

### Added

- `/ai:docs-sync` repo-hygiene + dead-links now honour project-local excludes (closes #98, closes #100):
  - Built-in defaults extended with `.pnpm-store`, `phpunit-storage`, `.archive`, `_originals`, `test-results`, `playwright-report`, `.vite-temp`, `coverage`, `.nyc_output`.
  - Active git worktrees (`git worktree list`) are auto-excluded — broken relative paths inside `.agents/worktrees/feat-x/...` stop drowning real findings. Only fires when the project path is the toplevel of its own git repo (no false-positives inside fixtures).
  - New `.docs-sync-ignore` file at repo root (gitignore-style subset): basenames without `/` extend the prune list; entries with `/` extend the path-prefix excludes. Comments + blank lines OK.
- `/ai:recommend-tools` now writes the graphify rule block to **both** `AGENTS.md` and `CLAUDE.md` when `.claude/` is present (closes #99). Prefers `graphify claude install` when the CLI is available; otherwise appends a fenced `<!-- ai-kit:graphify -->` block to `CLAUDE.md`. Auto-loading was the missing half — Claude Code only auto-reads `CLAUDE.md`.

### Removed

- `/ai:handoff` skill (stub since v1.35.0; was scheduled for v1.36.0, slipped). Use `/ai:checkpoint --to tmp` for transfer briefings. Refs cleaned from `docs/mental-model.md`, `docs/eval.md`, and `workflow/context/templates/AGENTS.md.template`. ADR-0009 retained as historical record.

### Notes

LEAN scope: shared exclude logic lives in `bin/lib/docs-sync-excludes.sh`, sourced by both scanners. No new flags, no JSON mode, no per-section opt-out. Test cases added: extra-default-excludes, docs-sync-ignore, git-worktree-exclude. Skill count: 38 → 37.

## 1.37.0 — 2026-05-27

### Added

- `/ai:hygiene` now always prints a `Score: N/100` install-quality grade at the end of the run — even on a fully clean repo (then it just shows "Score: 100/100" with no recipe). When below 100, a ranked "To reach 100:" recipe lists each non-clean section sorted blocker-first with the exact standalone script path to re-run for full detail. Rubric: start at 100, each blocker section −20, each warning section −5, clean 0; floor at 0.

### Notes

LEAN scope: scoring layer lives entirely in `bin/ai-kit-hygiene.sh`. No new flags, no JSON mode, no opt-out. Per-section name + exit code were already captured for the summary block — the scoring loop just sums them. Test (`tests/bin/cases/hygiene.sh`) covers fully-skipped-run-scores-100, real-run-format, and recipe-block-only-when-below-100.

## 1.36.0 — 2026-05-27

### Added

- `/ai:dedupe` Surface 5 now auto-inlines the per-item ecosystem-audit verdict table directly under its section header when `divergent > 0`. No more copying an absolute path and re-running `ai-kit-audit-ecosystem.sh` manually. EXCLUDED count is still surfaced separately above the table. (Closes #86.)
- `docs/auto-classifier-boundaries.md` — names the CC auto-mode classifier boundaries that ai-kit release flows hit (`~/.claude/**` writes; `claude plugin uninstall/install`), the tmpdir-clone workaround, and the "surface the user-runnable command" pattern. Cross-linked from `docs/troubleshooting.md`. (Closes #87.)

### Changed

- `bin/release.sh` tail replaces the one-line "Downstream" hint with an explicit numbered checklist for the user-runnable steps (`/plugin marketplace update`, `/plugin uninstall ai && /plugin install ai@yusufkaracaburun`, `/ai:upgrade` in downstream projects) — these can't run agent-side because the classifier blocks plugin lifecycle commands.
- `workflow/commands/dedupe.md` notes the new auto-inline behaviour so the summariser knows the verdict table is already on screen.

### Notes

`bin/release.sh --bump-marketplace` already encapsulated the tmpdir-clone pattern. This release is documentation + user-facing surfacing — no new primitive needed, the gap was the missing escape-hatch doc + the missing handoff postscript.

## Unreleased

## 1.35.0 — 2026-05-27

### Changed

- **Merged `/ai:handoff` into `/ai:checkpoint` (closes #91, ADR-0009).** One
  skill, one trigger, destination is an argument:
  - `/ai:checkpoint` (default `--to memory`) → same-project, same-machine
    resume; writes to auto-memory; pairs with `/ai:resume`.
  - `/ai:checkpoint --to tmp` → transfer briefing in `$TMPDIR` for another
    agent, machine, or teammate; redaction always-on.
  - `--mid-session` works for either target.
  - `/ai:handoff` slash kept for one release as a deprecation stub
    redirecting to `/ai:checkpoint --to tmp`; removed in v1.36.0.
  - Updated cross-refs in `/ai:resume`, `/ai:onboard`, and
    `standards/rules/context-discipline.mini.md`.
  - Eval prompt `tests/eval/prompts/handoff/mid-migration.md` now targets
    `skill: checkpoint` and asserts `--to tmp` + redaction.
  - Rationale: trigger overlap between the two skills was the actual pain;
    description-sharpening only fixed half. See ADR-0009 for the full
    reasoning and the rejected alternatives.

## 1.34.0 — 2026-05-27

### Changed

- **`/ai:hygiene` repo-skill-hint surfaces both project + framework
  docs-sync (closes #96).** `bin/ai-kit-repo-skill-hint.sh` now sources
  `bin/lib/applicability.sh` and, after listing any project-scoped
  hygiene-style skills under `.agents/skills/`, also surfaces the
  framework `/ai:docs-sync` when applicable (any markdown file present,
  `docs/` exists, or >1 local branch). When both apply, both are listed
  side-by-side with a one-line "use which for what" hint: project skill
  handles repo-specific drift (vocabulary, ADR triggers, status
  tables); framework skill handles universal drift (dead links,
  repo-hygiene, finished-work cleanup). Section stays silent when
  neither source has anything to surface. Tests: 16 asserts cover the
  matrix (both, project-skill-plus-framework, framework-only, neither)
  plus a negative wiring audit confirming the script reuses the
  shared applicability helper instead of duplicating detection.

### Notes

- Out-of-tree follow-up tracked separately: `naschool/.agents/skills/docs-sync/SKILL.md`
  should be slimmed to drop the three generic checks (dead-links,
  repo-hygiene, finished-work cleanup) now that `/ai:docs-sync` covers
  them framework-side. That PR lands in the naschool repo.

## 1.33.0 — 2026-05-27

### Added

- **/ai:docs-sync nudge wiring across checkpoint / ship / triage (closes
  #95).** New shared helper `bin/lib/applicability.sh` exposes
  `is_docs_sync_applicable` (true if `docs/` exists, or any `*.md` file
  is present, or the repo has >1 local branch) and
  `is_hygiene_applicable` (true if `.ai-kit-setup` marker is present).
  New thin wrapper `bin/ai-kit-docs-sync-nudge.sh [path] --context=...`
  prints a context-headed cross-cue ("Before clear, consider:" /
  "Closing this release? Consider:" / "After closing issues, consider:")
  listing the applicable commands; silent when neither applies. The
  three skill bodies now call the helper and surface its output verbatim
  — they never re-implement the applicability logic, so all surfaces
  stay in sync. Tests: 23 asserts cover the applicability matrix
  (docs/, markdown-only, >1 branch, marker, none, both), the three
  context headers, performance (<500ms wall budget for CI noise; <50ms
  target on a typical repo), and a negative wiring audit confirming no
  skill duplicates the helper logic.

## 1.32.0 — 2026-05-27

### Added

- **`/ai:docs-sync` — finished-work section (closes #94).** Detects
  local merged branches and closable GitHub issues. Default-branch
  detection: `git remote show origin` HEAD, falling back to `master`
  then `main`. Default branch, `HEAD`, and the currently-checked-out
  branch are always excluded from the merged-branch list. Closable
  issues come from a strict `(?<![A-Za-z])(?:closes|fixes|resolves)\s+#(\d+)`
  regex against the bodies of the 50 most recently merged PRs — `addresses #N`,
  `see #N`, and `for #N` are deliberately ignored. Fix flow: local
  branch delete is group-confirmable (`git branch -d` refuses unmerged
  as a safety net); remote-branch-delete (`git push origin --delete`)
  and `gh issue close` are **always individual y/N per item** — no
  `--yes-all` or `--batch` flag exists, by design. Skips cleanly on
  non-git repos, when no default branch can be detected, and when `gh`
  is unauthenticated. Tests: 18 asserts cover default-branch detection,
  current-branch exclusion, strict regex (no fuzzy match), no-batch-flag
  source audit, group-confirm accept path, and `--skip-finished-work`.

## 1.31.0 — 2026-05-27

### Added

- **`/ai:docs-sync` — repo-hygiene section (closes #93).** Three
  mechanical `find`-based sub-checks: empty directories (excludes
  `.git`, `node_modules`, `vendor`, `.tmp`, `dist`, `build`, `.next`,
  `.turbo`, `.cache`), broken symlinks (portable detection — no
  GNU `-xtype l`), and orphan `.agents/skills/<name>/` dirs that
  lack a `SKILL.md`. Empty-dir + broken-symlink fixes are
  group-confirmable behind one `y/N` prompt (rmdir + rm). Orphan
  skill dirs are report-only — never auto-deleted, since the dir
  may be in-progress work. `--skip-repo-hygiene` bypasses the
  section. Tests: 29 asserts cover all #93 acceptance criteria,
  including the no-prompt safety path, the accept path (via
  `AI_KIT_DOCS_SYNC_TEST_AUTO_YES=1` test-only env var), and the
  orphan-skill-dir never-deleted guard.

## 1.30.0 — 2026-05-26

### Added

- **`/ai:docs-sync` — standalone content-drift skill (closes #92).**
  Splits content-drift concerns out of `/ai:hygiene` (which stays focused
  on framework wiring health). New driver `bin/ai-kit-docs-sync.sh` runs
  sectioned checks against the project, exits 0 (clean) or 1 (findings).
  First section: **dead-links** — scans every `*.md` for inline
  `[text](path)` links, verifies relative + repo-absolute targets exist on
  disk, and reports `file:line` + missing path per finding. Code fences,
  image links, HTML `<a href>`, bare URLs, external schemes, and anchor-
  only links are deliberately excluded. Anchor fragments are stripped
  before path-existence check (no anchor validation). SKILL.md locks
  6 non-goals (ADR-trigger detection, TODO-completion, status-table
  drift, persona/PII grep, structure-convention, code-comment-as-doc
  parsing) so v2 scope creep gets bounced. Tests: 30 asserts cover all
  acceptance criteria from #92. Follow-up issues #93 / #94 add repo-
  hygiene + finished-work checks; #95 wires nudge integrations; #96
  teaches `repo-skill-hint` to surface both surfaces.

## 1.29.0 — 2026-05-26

### Changed

- **Split `ai-kit-audit-ecosystem.sh` god-script (closes #89).**
  590-LOC dispatcher refactored into 7 sourced libs under
  `bin/lib/audit-ecosystem/` (common, plugins, marketplaces, skills,
  agents, rules, mcp, render). Slim dispatcher (~170 LOC) now only
  handles argument parsing, self-detection, sourcing, and the
  walk → render → exit sequence. Behaviour preserved — all 27
  audit-ecosystem regression tests still pass.

### Added

- **`bin/count-primitives.sh` — single-source primitive counts
  (closes #90).** Emits canonical counts as JSON (default), one-line
  human-readable (`--human`), or drift-check (`--check`). The
  drift-checker greps user-facing docs (`README.md`,
  `docs/architecture.md`, `docs/install-plugin.md`,
  `docs/mental-model.md`, `ONBOARDING.md`, `plugin.json`) for the
  expected count substrings and fails CI when reality diverges from
  any tracked surface. Wired into `.github/workflows/eval.yml` as the
  third eval step. New regression test case `count-primitives` covers
  all three modes + synthetic drift detection (14 asserts).

## 1.28.1 — 2026-05-26

### Fixed

- **Self-audit P0/P1 fixes.** /ai:audit-architecture on ai-kit itself
  surfaced 9 🟠 findings. Quick wins landed inline:
  - **D5 comment-drift on primitive counts.** README, plugin.json,
    docs/architecture.md, docs/install-plugin.md, docs/mental-model.md,
    ONBOARDING.md all synced to reality: 37 skills · 10 commands ·
    30 canonical rules. Root cause (no single source) tracked in
    [#90](https://github.com/yusufkaracaburun/ai-kit/issues/90).
  - **D5 ADR-0004 misleading after v3.0 rename.** Added a Superseded
    banner; the `aikit-` prefix is no longer required — invocation
    is plugin-scoped as `/ai:<skill>` now.
  - **D8 strict-mode rationale comments** on warning-collector scripts
    (`ai-kit-doctor.sh`, `ai-kit-dedupe.sh`, `ai-kit-audit-ecosystem.sh`)
    explaining why `-e`/`-u` are intentionally omitted.
  - **D4 empty `.planning/`** directory removed.
  - Bigger lifts deferred: god-script split
    ([#89](https://github.com/yusufkaracaburun/ai-kit/issues/89)),
    single-source primitive counts
    ([#90](https://github.com/yusufkaracaburun/ai-kit/issues/90)).

## 1.28.0 — 2026-05-26

### Added

- **`/ai:audit-architecture-shadcn` extension.** New
  `workflow/skills/audit-architecture-shadcn/SKILL.md` adds 6
  shadcn/ui-specific heuristics (S1-S6: `cn()` merge discipline, `cva()`
  variant extension, `forwardRef` contract on primitives, deep-relative
  import-path drift away from declared aliases, cross-primitive coupling
  inside `components/ui/`, `components.json` alias drift). Auto-loads
  alongside the React extension when `components.json` declares the
  `https://ui.shadcn.com/schema.json` schema (detected via the new
  `shadcn` framework key in `bin/lib/detect-lib.sh`).

## 1.27.0 — 2026-05-26

### Changed

- **`autonomous` skill promoted out of SPIKE.** Multiple real-queue
  drains in `ai-kit` and `naschool` validated the cold-start /
  fresh-context invariant + `progress.txt` discipline; no contract
  changes versus the spike draft. README "Experimental" row replaced
  by "Automation"; spike doc preserved at
  `docs/spikes/aikit-autonomous-ralph.md` with a PROMOTED banner.

### Added

- **`/ai:audit-architecture-nextjs` extension.** New
  `workflow/skills/audit-architecture-nextjs/SKILL.md` adds Next.js
  App-Router-specific heuristics (server/client boundary, `use server`
  payload safety, RSC streaming + caching, route handler typing,
  middleware scope, `next/image` + `next/font` discipline). Auto-loads
  alongside the React extension via
  `bin/audit-extension-loader.sh` when a `next.config.{js,mjs,ts}` or
  Next dependency is present.

- **CI workflow for eval-suite.** New `.github/workflows/eval.yml`
  runs `tests/bin/eval-structure.sh` and
  `bin/eval-golden.sh --validate-all` as a dedicated job on push to
  `master` and on PRs. Provides external visibility into eval-suite
  health (structural + rubric) and gates regressions before merge.

## 1.26.0 — 2026-05-26

### Added

- **`/ai:hygiene` — memory-audit now scans every typed subdir of
  `.agents/memory/`** (typically `feedback/`, `reference/`, `decisions/`,
  `patterns/`, `project/`), not just `feedback/`. Orphan + stale logic is
  identical per bucket; `README.md` index files are ignored. Output names
  the buckets it scanned so the user sees coverage at a glance.

- **`/ai:hygiene` — repo-skill-hint section.** New
  `bin/ai-kit-repo-skill-hint.sh` lists project-scoped skills under
  `.agents/skills/` whose name or description matches hygiene-style
  triggers (docs-sync, doc-drift, repo-hygiene, housekeep, prune,
  cleanup, audit). The hint points at `/skill-name` instead of
  duplicating repo-specific content in ai-kit. Wired into
  `bin/ai-kit-hygiene.sh` as section 5 with `--skip-repo-skills` flag.
  Report-only; skips silently when no `.agents/skills/` exists.

## 1.25.0 — 2026-05-26

### Added

- **`/ai:hygiene` — memory-audit section.** New `bin/ai-kit-memory-audit.sh`
  scans `.agents/memory/feedback/*.md` for ORPHAN entries (not indexed in
  `.agents/memory/MEMORY.md`) and STALE entries (>90d untouched + 0 refs).
  Wired into `bin/ai-kit-hygiene.sh` as the 4th section with `--skip-memory`
  flag. Report-only; skips silently when no `.agents/memory/feedback/`
  directory exists.

- **`/ai:audit-architecture` per-stack extensions — v1 big-bang** (EPIC
  [#35](https://github.com/yusufkaracaburun/ai-kit/issues/35), ADR-0008).
  The stack-agnostic audit skill now auto-loads stack-specific extensions
  via `bin/audit-extension-loader.sh` whenever a matching framework or
  language is detected.

  Three extensions land in this release, each shipping a triplet (skill +
  rule + helper-script + fixture):

  - **`audit-architecture-laravel`** ([#80](https://github.com/yusufkaracaburun/ai-kit/issues/80))
    — 22 strict heuristics across the 9 audit dimensions. Always-on
    strict mode (severity floor 🟡; API findings L13-L18 floor at 🟠).
    Detects `api-only` vs `full-stack` mode via `routes/api.php` +
    Inertia/Livewire/Blade markers. Helper-script gates Larastan,
    `composer outdated`, `php artisan about`.
  - **`audit-architecture-react`** ([#81](https://github.com/yusufkaracaburun/ai-kit/issues/81))
    — 8 React 19 heuristics, including the RSC server/client boundary
    leak (R6) and React 19-specific server-action typing (R7). Default
    strictness. Helper-script gates ESLint + `tsc --noEmit`. Matches
    `react`, `nextjs`, `remix`.
  - **`audit-architecture-typescript`** ([#82](https://github.com/yusufkaracaburun/ai-kit/issues/82))
    — 8 framework-agnostic language-level heuristics (any-leak,
    as-cast-past-edge, exhaustive-switch, decorator/runtime,
    duplicated-type-alias, unused-type-export, readonly drift,
    overloads-as-discriminated-union). Fires alongside React/Vue/Next
    extensions. Helper-script gates `tsc --noEmit --strict`
    (force-strict regardless of project tsconfig), `ts-prune`, ESLint
    `@typescript-eslint/strict` subset.

  Total v1 surface: 38 new heuristics encoded as `.mini.md` rules. The
  React + TypeScript ownership boundary is enforced by the shared
  `tests/fixtures/audit-react-ts-overlap/` fixture (each finding row
  appears exactly once across `[react]` and `[typescript]` prefixes).

  Flutter extension ([#83](https://github.com/yusufkaracaburun/ai-kit/issues/83))
  is deferred to v2 pending a real Flutter project.

  New env vars:

  - `AI_KIT_AUDIT_NO_EXTEND=1` — skip extension loading entirely; run
    vanilla baseline audit.
  - `AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack` — override
    detected mode for the Laravel extension.

  See `docs/adr/0008-audit-architecture-extensions.md` for the twelve
  design decisions frozen during the 2026-05-26 grilling session, and
  `standards/contracts/audit-architecture-extension.contract.md` for
  the contract every future extension must satisfy.

## 1.24.0 — 2026-05-26

### Added

- **Canonical feedback-rules layer** (#30, ADR-0007). New
  `standards/rules/feedback/` subdir under canonical rules, emitted by
  default at `/ai:setup` so every new project inherits cross-project
  workflow / style / tool-gotcha defaults instead of re-discovering
  them per project. v1 set (all `universal: true`):
  `phase-scope-discipline`, `branch-cleanup-after-merge`,
  `deployment-on-demand`, `minimal-comments`, `latest-stable-deps`
  (defers to `project-lifecycle` for production phase),
  `mark-recommended-option`, `bsd-sed-word-boundary`,
  `gitignore-public-assets-trap`. Emitter recursion patched into
  `bin/emit-rules.sh`, `bin/lib/recommend-lib.sh`,
  `bin/ai-kit-audit-ecosystem.sh`, `bin/ai-kit-dedupe.sh` so
  feedback-rules are first-class to every downstream consumer.
  `/ai:setup` Branch 12 and `/ai:recommend-rules` Phase 1 name the
  feedback bucket explicitly. `standards/promotion-quorum.md` gains a
  sibling section documenting the manual feedback-rule promotion flow
  (ai-kit-lessons → GH issue → curate during release).

- **`/ai:upgrade` prints CHANGELOG slice between versions.** After
  re-stamping `.ai-kit-setup`, the script slices the relevant
  CHANGELOG section between the old marker version and the new one
  and prints it so the user sees what changed across the upgrade
  without cracking open CHANGELOG.md. Silent skip on same-version /
  unknown-old / missing CHANGELOG / no matching headings.

### Fixed

- **Plugin packaging shipped no `context/`** — `setup-gh-workflow.sh`,
  `bootstrap-project.sh`, `apply-docker.sh`, and several skills
  resolve templates / prompts via `$AI_KIT_ROOT/context/**`, and the
  cached plugin install hard-exited with `Templates missing:
  <root>/context/templates/github` (or silently skipped: PR-template
  scaffold, Docker apply). Root cause: ai-kit had no mirror script
  for `context/` and the release flow never sync'd `standards/`
  either. Fix: new `bin/sync-plugin-context.sh` mirror script,
  symmetric to the existing sync-plugin-{bin,hooks,standards}; release
  flow now calls both `sync-plugin-standards.sh` and
  `sync-plugin-context.sh`. Three new asserts in `structure.sh` lock
  the invariant. Doctor's "PR template missing — run
  /ai:setup-gh-workflow" warning no longer chases a dead link.

### Docs

- `bin/setup-gh-workflow.sh` header comment listed only steps 1–4
  (issue templates, workflows, labels, project board) — the script
  also scaffolds the PR template (step 5) and applies branch
  protection (step 6) since #66. Docblock now in sync.

### Tests

- `tests/bin/cases/release-install.sh`: `which --list` skill-count
  assert bumped from 30 → 32 (audit-fix + doc-to-skill landed in
  v1.23.0 without bumping the hardcode).
- `tests/bin/cases/structure.sh`: skill-count assert bumped from 30
  → 32; three new asserts cover `sync-plugin-standards --check`,
  `sync-plugin-context --check`, and
  `workflow/context/templates/github` presence in the plugin tree.
- `tests/bin/cases/bootstrap-emit.sh`: `--list` count assert bumped
  from 26 → 34 to cover the eight new feedback-rules.
- `tests/eval/prompts/audit-fix/finding-a1.md` and
  `tests/eval/prompts/doc-to-skill/pdf-to-scaffold.md`: missing eval
  scenarios added so `eval-structure` is clean again.

Test suite: 585 / 585 green.

## 1.23.0 — 2026-05-26

### Added

- **`/ai:audit-fix` skill** (#34) — consumes `/ai:audit-architecture`
  reports and applies atomic per-finding fixes. One commit per
  finding, per-finding user approval (or `--batch` with severity
  filter), affected-paths-only scope, scoped verification before
  commit, read-after-write re-run on the dimension, report row
  rewritten to `✅ fixed` with closing commit SHA. Refusal cases for
  scope-creep, bundling, missing fields, and behaviour-change risk.
- **`/ai:doc-to-skill` skill + `bin/doc-to-skill.sh`** (#45) — converts
  a single PDF / EPUB / DOCX / RTF / ODT / MD into a `SKILL.md`
  scaffold with frontmatter, claim placeholders, chapter index from
  source headings, sources list, and provenance credit to
  `virgiliojr94/book-to-skill` (MIT). Pure bash + pandoc — pandoc is a
  system dep, not added to the repo. Defaults output path to
  `workflow/skills/` when run inside ai-kit, `./skills/` in consumer
  repos. Refuses to overwrite an existing `SKILL.md`.

### Fixed

- **#26 closed** as already-shipped — Tier 1 path-pattern triggers in
  `bin/hooks/context-drift-check.sh` landed in commit `3a64907` ahead
  of this triage pass. Issue verified against AC; no new code needed.

## 1.22.0 — 2026-05-26

### Added

- **Promotion quorum for recommend-\*** (#46). New
  `standards/promotion-quorum.md` codifies the ≥2-independent-sources
  bar a community rule / tool / pattern must clear before
  `/ai:recommend-rules` or `/ai:recommend-tools` marks it as default-on.
  Single-source entries are still surfaced — labeled `(sources: 1 —
  preview only)` and never pre-selected. Both recommend-\* SKILL.md
  surfaces reference the doc and carry the annotation contract with
  worked examples.

### Changed

- **`/ai:autonomous` step 0** gains three preflight checks adopted from
  the OpenHands research arc (#21):
  - Per-conversation `AI_KIT_ROOT` pinning from the Agent Brief's
    `ai_kit_root:` key (falls back to existing resolver).
  - Triage-labels-exist precondition: refuses to drain when the
    `ready-for-agent` label is missing on the tracker.
  - Per-project merge-policy detection (brief → `.ai-kit-setup` → git
    config → default `pr`). Brief-vs-project disagreement halts via new
    `exit-gate merge-policy-mismatch`.
  New event family `preflight-*` lands in the `progress.txt` schema so
  the cold-readable log shows step 0 ran clean before the first `pick`.

### Docs

- **`docs/spikes/aikit-autonomous-ralph.md`** — new section "Research
  input: OpenHands patterns". 6-row comparison table mapping
  `All-Hands-AI/OpenHands` patterns (sandbox-per-session, status state
  machine, event store, workspace-volume per id, no-autonomous-picker,
  pre-flight phases as first-class) to the three spike contract gaps,
  with adopt / adopt-with-modification / reject decisions per pattern.

## 1.21.0 — 2026-05-26

### Added

- **/ai:setup Tier-A Branch 2c — Universal MCPs auto-prompt** (#51). MCP
  servers marked `universal: true` in `standards/external/mcp-servers.json`
  (today: `context7`; future-proof for more) are now auto-prompted during
  Tier-A setup instead of waiting for a `/ai:recommend-tools` follow-up.
  Per-tool prompt, never silent install. Idempotent: a new
  `--universal-mcps-prompted=...` flag on `bin/write-setup-marker.sh`
  accumulates handled names in `.ai-kit-setup` so re-runs skip them. Adding
  a new `universal: true` entry to the MCP catalog is picked up
  automatically — no skill-body edit required.
- **Catalog: three new plugin entries in `standards/external/plugins.json`**
  (#42 #43 #44):
  - `context7@claude-plugins-official` — live library docs MCP, pairs with
    the canonical context7 rule.
  - `claude-code-setup@claude-plugins-official` — general-purpose Claude
    Code automation recommender; complementary to `/ai:setup` and
    `/ai:recommend-tools`.
  - `caveman@caveman` (JuliusBrussee/caveman) — ultra-compressed
    communication mode + subagent-output compression.

  All three carry `universal: true`. `bin/ai-kit-audit-ecosystem.sh` now
  reports each as OWNED instead of ADOPT-divergent.

### Changed

- `standards/external/companions.json`: context7's `tiers[0]` entry gains
  `auto_prompted: true` and a wiring pointer to `setup/SKILL.md` Branch 2c
  so `bin/audit-setup-symmetry.sh` stays consistent with the new auto-prompt
  flow.

## 1.20.3 — 2026-05-25

### Added

- **2-dev default sweep ([#52](https://github.com/yusufkaracaburun/ai-kit/issues/52))** — ai-kit defaults now assume ≥2 devs (writer + reviewer) instead of solo. Eight slices merged under one parent:
  - `setup-gh-workflow` ([#66](https://github.com/yusufkaracaburun/ai-kit/issues/66)): hybrid `gh api PUT` branch-protection (403 → checklist fallback, exits 0); scaffolds `.github/PULL_REQUEST_TEMPLATE.md` with DoR/DoD checkboxes; new `--no-protection` / `--no-pr-template` flags; `--dry-run` emits payload + fallback command.
  - `triage` + `to-issues` ([#65](https://github.com/yusufkaracaburun/ai-kit/issues/65)): explicit "Second-dev cold-pickup" rule pointing to #52.
  - `tdd` ([#63](https://github.com/yusufkaracaburun/ai-kit/issues/63)): new "Review (required)" phase with single-human-project clause.
  - `ship` ([#63](https://github.com/yusufkaracaburun/ai-kit/issues/63)): review-before-merge stated as precondition, not recommendation.
  - `autonomous` ([#68](https://github.com/yusufkaracaburun/ai-kit/issues/68)): Trust-model gains explicit "Agent is the writer; the reviewer is human" rule with solo-human caveat.
  - `setup` + `onboard` ([#62](https://github.com/yusufkaracaburun/ai-kit/issues/62)): two surviving team-size "solo" hits rewritten in 2-dev framing. Install-layout `setup_mode=solo-*` vocabulary preserved.
  - AGENTS.md / CLAUDE.md templates ([#64](https://github.com/yusufkaracaburun/ai-kit/issues/64)): new "Team shape" section documents the "we" / 2-dev default.

- **`/ai:doctor` single-dev drift checks ([#69](https://github.com/yusufkaracaburun/ai-kit/issues/69))** — three new warn-only checks in GitHub repos: PR template missing, branch-protection off (skipped on 403 / non-admin), single-committer in last 30d (gated on ≥5 commits). All warn (never error). `/ai:hygiene` inherits via its existing doctor call.

- **`/ai:doctor` workflow-text solo lint ([#70](https://github.com/yusufkaracaburun/ai-kit/issues/70))** — regression guardrail across `workflow/skills/**/*.md` + `workflow/commands/**/*.md`. Locks the baseline at zero team-size solo/single-dev hits. Whitelists install-layout vocab, rule-discussion idioms (`solo-human`, `single-dev shortcut`), and per-line `solo-lint:allow` directive.

### Fixed

- **`recommend-tools` companions disambig ([#53](https://github.com/yusufkaracaburun/ai-kit/issues/53))** — `graphify-wiki` (AST-derived at `graphify-out/wiki/`) and `llm-wiki` (curated at `wiki/`) now name themselves uniquely; glue templates carry a disambig footer; `companions.json` cross-refs both ways; `recommend-tools` SKILL emits a "Two wikis present" block in AGENTS.md when both companions are wired.

### Audited

- **`recommend-tools` solo-heuristic audit ([#67](https://github.com/yusufkaracaburun/ai-kit/issues/67))** — grep across `workflow/skills/recommend-tools/` + scorer + JSON catalogs returned zero hits. recommend-tools already scores per stack-signal; no team-size heuristics existed to drop. Closed with evidence comment, no code change.

### Tests

- Total assert count: 506 → 575 (69 new). New test cases: `companions-disambig` (7), `we-pronouns` (4), `setup-gh-workflow-protection` (14), `setup-onboard-no-solo` (7), `cold-pickup-rule` (8), `autonomous-writer-reviewer` (6), `tdd-ship-review-required` (9), `single-dev-drift` (15), `doctor-workflow-solo-lint` (10).

## 1.20.2 — 2026-05-25

Patch: `ai-kit-audit-ecosystem.sh` now surfaces deliberately-excluded plugins
with a dedicated `EXCLUDED` verdict instead of conflating them with `REPLACE`
(which is reserved for user-scope skill/agent shadowing). The audit's
`--converge` mode emits a `/plugin uninstall` command per EXCLUDED finding
with the recorded alternative from `standards/external/plugins-excluded.json`,
and `/ai:dedupe` Surface 5 calls out the EXCLUDED count distinctly so
`/ai:hygiene` inherits the signal.

Before: an installed superpowers (or any other excluded plugin) was emitted
as `REPLACE` next to user-scope skill/agent shadowing. The plugins-excluded
catalog knew the plugin shouldn't be there, but the verdict was lossy.

After: `verdict: "EXCLUDED"` carries the recorded reason verbatim, the
converge recipe prints the uninstall command, and the dedupe summary states
"N EXCLUDED plugin(s) installed — ai-kit ships equivalents, uninstall
suggested." Trust-model unchanged — never auto-uninstalls.

- **Fix** `bin/ai-kit-audit-ecosystem.sh`: emit `EXCLUDED` (was `REPLACE`) for
  plugins matching `plugins-excluded.json`; counted as divergent; new converge
  case for `plugins/EXCLUDED` surfaces uninstall + alternative hint.
- **Fix** `bin/ai-kit-dedupe.sh`: extract `ECOSYSTEM_EXCLUDED` from ecosystem
  JSON; Surface 5 prints a distinct EXCLUDED line when present.
- **Docs** `workflow/commands/dedupe.md`: extend Surface 5 verdict-token list
  with `EXCLUDED`; tighten `REPLACE` meaning to user-scope shadowing only.
- **Tests** `tests/bin/cases/audit-ecosystem.sh` + `tests/bin/cases/dedupe.sh`:
  new assertions for verdict, divergent counting, converge output, and human
  surfacing via real-catalog HOME-override fixture.
- **Chore** Re-sync `workflow/bin/` from `bin/` (pre-existing drift on
  `audit-setup-symmetry`, `bootstrap-project`, `emit-agents`, `eval-skill`,
  `install-global`, `lib/detect-lib`).

Closes [#54](https://github.com/yusufkaracaburun/ai-kit/issues/54).

## 1.20.1 — 2026-05-25

Patch: `emit-rules.sh` now resolves the ai-kit version via the shared
`resolve_ai_kit_version` helper (with `plugin.json` fallback) instead of
requiring a `VERSION` file at the script's parent root. Plugin installs
ship the `workflow/` subdir without `VERSION` at top level, so the old
hard-coded read failed with `ai-kit VERSION file missing` and exit 2 —
blocking `/ai:recommend-rules` Phase 3 emit and any direct
`emit-rules.sh` call on a plugin-only install.

- **Fix** `bin/emit-rules.sh` + `workflow/bin/emit-rules.sh`: use
  `resolve_ai_kit_version "$AIKIT"`, same migration the other bin/
  scripts already had (`verify-setup.sh`, `ai-kit-upgrade.sh`,
  `ai-kit-doctor.sh`, `ai-kit-status.sh`).

Closes [#55](https://github.com/yusufkaracaburun/ai-kit/issues/55).

## 1.20.0 — 2026-05-25

### Added

- **`branches.lifecycle` in `.ai-kit-setup`** — new orthogonal signal (`development` | `production`) calibrates default agent caution per project lifecycle phase. Missing key defaults to `production` (safe-by-default, no regression for existing installs). Closes [#56](https://github.com/yusufkaracaburun/ai-kit/issues/56), [#58](https://github.com/yusufkaracaburun/ai-kit/issues/58).
- **`standards/rules/project-lifecycle.mini.md`** — new canonical rule (universal=true, always-on, weight=high). Emits a 5-axis behaviour contract (schema migrations / backwards-compat / defensive code / destructive ops / feature flags) with both columns visible so the LLM can calibrate edge cases. Lands in `.claude/rules/project-lifecycle.md` + `docs/agents/active-rules.md` via the existing emit-rules pipeline.
- **`bin/write-setup-marker.sh --lifecycle=development|production`** — new flag persists the phase in the marker. Rejects invalid values with exit 2 + clear error.
- **`/ai:setup` Branch 2b** — Tier-A lifecycle prompt; default `development` for fresh greenfield, `production` for brownfield setup-mode. Re-runs follow the existing keep/change/skip pattern. Closes [#59](https://github.com/yusufkaracaburun/ai-kit/issues/59).
- **`/ai:phase <development|production>`** — new lightweight skill flips the lifecycle key without re-running `/ai:setup`. No-arg form prints the current phase. Surfaces the script's `lifecycle: <old> → <new>` transition + restart-Claude-Code reminder verbatim — the canonical rule reloads only on next session. Closes [#60](https://github.com/yusufkaracaburun/ai-kit/issues/60).
- **`/ai:status`** — surfaces `lifecycle=<value>` alongside the existing branch summary, with the same `// "production"` fallback.

### Tests

- `tests/bin/cases/structure.sh` bumped to 30 skills / 10 slash commands; the per-command loop now covers `phase`.
- `tests/bin/cases/release-install.sh` bumped `which --list` row count to 30.
- `tests/bin/cases/bootstrap-emit.sh` bumped `emit-rules --list` row count to 26.
- `tests/eval/prompts/phase/flip-to-production.md` — new eval fixture covering invoke-the-script / don't-re-run-setup / surface-transition+reminder / reject-invalid-without-retry / read-marker-not-guess.

## 1.19.0 — 2026-05-25

### Added

- **`/ai:rename-housekeeping <old> <new>`** — new skill that rewrites stale absolute-path references in memory files after a local repo rename or move. Scans `~/.claude/CLAUDE.md`, project `CLAUDE.md`/`AGENTS.md`/`.agents/memory/**`/`.planning/**`/`docs/**`/`.claude/**`, and `~/.cursor`/`~/.codex`/`~/.gemini`. Dry-run preview → confirm → snapshots every `~/.claude/**` target to `~/.claude/.backups/<ts>/` before write → updates `~/.claude/known-projects.json`. Closes [#33](https://github.com/yusufkaracaburun/ai-kit/issues/33).
- **`bin/hooks/rename-detector.sh`** — user-global `SessionStart` hook that maintains `~/.claude/known-projects.json` (`name`, `path`, `first_seen`, `last_seen`). Emits a one-line nudge only when `basename($PWD) == known.name && $PWD != known.path && ! test -d known.path`. Multi-clone case (both paths still on disk) stays silent and registers a disambiguated second entry.
- **`bin/install-rename-hook.sh`** — idempotent installer that wires the hook into `~/.claude/hooks/` and non-destructively merges a `SessionStart` entry into `~/.claude/settings.json`. Refuses to overwrite malformed JSON. `--uninstall` cleanly reverses both.
- **`/ai:setup` Branch 11b** — "install global rename-detector?" one-line prompt; gated on whether the hook is already wired.

### Tests

- `tests/bin/cases/rename-housekeeping.sh` adds 30 assertions across structure, fake-rename, known-projects-update, hook-rename, multi-clone-guard, installer idempotency, and corrupt-`settings.json` refusal.
- `tests/eval/prompts/rename-housekeeping/post-mv.md` eval fixture closes the missing-fixture warning.

## 1.18.2 — 2026-05-25

Patch: context7 detection now catches plugin-provided installs (not
just user-scope MCPs).

Live incident on 2026-05-25 in a fresh session: ai-kit ran
`claude mcp list | grep -q context7`, saw nothing, told the user
"NOT_INSTALLED", then `claude mcp add --scope user context7` — but
the `context7@claude-plugins-official` plugin was already installed
and providing the same MCP. Result: `/doctor` reported
"MCP server context7 skipped — same command/URL".

Root cause: `claude mcp list` only shows user-config MCPs and
currently-connected plugin MCPs. Plugin-provided MCPs that aren't
active in the current project are invisible. Detection must check
both surfaces.

- **Fix** `standards/external/companions.json` → context7 entry: detection
  now checks both `claude mcp list` AND `claude plugin list`; new
  `conflicts[]` entry warns about the plugin-vs-user-scope clash;
  install block names the plugin path as preferred.
- **Fix** `standards/external/mcp-servers.json` → context7 entry: new
  `install_paths` block documenting preferred plugin path, fallback
  user-scope command, correct detection one-liner, and a conflict_note.
- **Fix** `workflow/skills/recommend-tools/SKILL.md` Phase 1 detection
  now emits a context7 line that combines both checks before
  recommending anything.

## 1.18.1 — 2026-05-25

Patch: ship `bin/ai-kit-hygiene.sh` + updated `bin/audit-setup-symmetry.sh`
in the plugin install.

v1.18.0 added the script + symmetry-audit changes to repo-root `bin/`
but skipped `bin/sync-plugin-bin.sh`, so `workflow/bin/` (the
plugin-install source) never received the files. `/ai:hygiene` resolved
`${CLAUDE_PLUGIN_ROOT}/bin/ai-kit-hygiene.sh` to a non-existent path on
every install.

- **Fix** `workflow/bin/ai-kit-hygiene.sh` — now mirrored from
  `bin/ai-kit-hygiene.sh`.
- **Fix** `workflow/bin/audit-setup-symmetry.sh` — re-synced so the
  recommend-tools/SKILL.md wiring-path check ships in the plugin.

Process gap that allowed this: the release flow has
`bin/sync-plugin-bin.sh --check` available but the manual commit path
did not invoke it. Adding a pre-commit guard for `workflow/bin/` drift
is a follow-up.

## 1.18.0 — 2026-05-25

Minor: one-shot hygiene command + companion-tool catalog + graphify
wiki tier + llm-wiki conflict-detection.

### `/ai:hygiene` — one-shot housekeeping

ai-kit shipped three separate housekeeping scripts (`ai-kit-doctor.sh`,
`ai-kit-dedupe.sh`, `audit-setup-symmetry.sh`) but no chat-callable
aggregator. Users had to remember each script and run them one by one.
The drift-check hook auto-fires on Edit/Write in client repos, but
install-health, duplicate detection, and catalog-symmetry have no
auto-trigger anywhere.

- **New** `bin/ai-kit-hygiene.sh` — orchestrates doctor + dedupe +
  audit-setup-symmetry in sequence with section headers; exit code =
  max of the three (0 clean, 1 warn, 2 block). Skip flags:
  `--skip-doctor`, `--skip-dedupe`, `--skip-symmetry`.
- **New** `/ai:hygiene` slash command — wraps the script and summarises
  per-section findings with routing hints (`/ai:setup`,
  `bin/sync-plugin-version.sh`, `/ai:dedupe --fix`, …). Reports only;
  never deletes.

### `standards/external/companions.json` — companion catalog

The four companions (graphify, caveman, llm-wiki, context7) lived as
hard-coded prose inside `recommend-tools/SKILL.md`. New companions
could not be added without editing the skill body, and
`audit-setup-symmetry.sh` had no signal to flag missing wiring paths.

- **New** `standards/external/companions.json` — vendored catalog
  documenting each companion's tiers, detection signals, glue files,
  and conflict checks. Same provenance frontmatter pattern as the
  other `standards/external/*.json` tables.
- **Updated** `bin/audit-setup-symmetry.sh` — recognises a third
  wiring path: `workflow/skills/recommend-tools/SKILL.md` (companions
  branch, non-scored judgement-based recommendations). Companions
  failing to reference their catalog entry will block setup-symmetry
  audit.
- **Updated** `recommend-tools/SKILL.md` — references the catalog as
  source of truth; per-companion behaviour now derives from the JSON.

### `graphify --wiki` opt-in tier + post-run nudge

graphify supports `graphify . --wiki` (AST-only, no LLM cost) — a
generated Markdown wiki under `graphify-out/wiki/` that beats per-query
subgraphs for symbol-lookup navigation. The flag was undocumented in
ai-kit; users never knew to consider it.

- **Updated** `recommend-tools/SKILL.md` Phase 1 (Detect) — emits a
  separate line for the wiki tier so the recommendation can branch on
  presence/absence.
- **Updated** `recommend-tools/SKILL.md` Phase 3 (graphify branch) —
  adds step 5 documenting the opt-in tier with an explicit decision
  rule: recommend only when the user asks, the repo is large, or the
  recent transcript shows >3 grep/find calls for symbol locations.

### `llm-wiki` conflict-detection with existing `docs/`

llm-wiki scaffolded `wiki/` + `raw/` without checking whether the
project already had a curated `docs/` tree. The agent risked "helpfully
consolidating" existing docs into the wiki — eroding the boundary
between human-curated material (`docs/`) and agent-derived material
(`wiki/`).

- **Updated** `recommend-tools/SKILL.md` Phase 3 (llm-wiki branch) —
  adds an explicit Conflict-check step 1: surface the warning from
  `companions.json` verbatim before scaffolding; the agent must never
  relocate, rewrite, or "consolidate" files under existing `docs/`
  into `wiki/`. AGENTS.md pointer block now spells out the
  docs/ ↔ wiki/ boundary explicitly when both coexist.

## 1.17.1 — 2026-05-25

Patch: ship a starter `.graphifyignore` with the graphify companion.

Without an ignore list, `graphify .` scans `node_modules/`, `vendor/`,
build outputs, lockfiles, binary assets, and recursively
`graphify-out/` itself — producing a junk-laden graph on any real
Laravel / Node / Vite repo. Users had to discover this and write an
ignore file by hand after the first run.

- **New** `context/templates/companions/graphifyignore` — 84-line
  starter list covering PHP/Laravel (`vendor/`, `backend/storage/`,
  `backend/bootstrap/cache/`, …), Node/pnpm (`node_modules/`,
  `.pnpm-store/`), build outputs (`dist/`, `.next/`, `.vite/`, …),
  IDE/OS dirs, agent scratch (`.agents/worktrees/`,
  `.claude/tdd-guard/`, …), lockfiles, binary assets, logs, and
  `graphify-out/` itself. Stack-agnostic + common monorepo
  `backend/*` paths — lines for absent paths are no-ops.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — Phase 3
  graphify gains a new step 3: copy template to project root as
  `.graphifyignore`, **skip if present** (never clobber a project's
  own ignore list). Phase 4 "Wired" line mentions `.graphifyignore`
  when newly written.
- **Updated** `context/templates/companions/README.md` — table row
  for the new glue file.
- **Updated** `context/templates/companions/graphify.md` — one extra
  AGENTS.md rule line: "tune `.graphifyignore` at the project root
  before the first `graphify .` run".

Trust posture unchanged: ai-kit writes glue, never auto-runs
`graphify .`. User still triggers init themselves.

## 1.17.0 — 2026-05-25

Closes #50 (subagent recommendations) and #48 (setup-symmetry lock).
Closes #49 retroactively — verified that `standards/external/plugins.json`
was already wired via the `recommend-tools` scorer from v1.12.x; the
issue scope (separate `recommend-plugins` skill) would have duplicated
~80% of `recommend-tools` plumbing. Branch 14 (#19, v1.16.0) already
surfaces plugins through `recommend-tools.sh --kind plugin`.

The remaining work: extend the same recommend-tools surface to subagents
and lock the symmetry principle so future catalogs cannot land without
a wiring path.

- **New** `standards/external/subagents.json` — initial entries:
  `claude-code-guide` (universal docs subagent), `caveman:cavecrew-
  investigator` / `cavecrew-builder` / `cavecrew-reviewer`. Schema
  mirrors `plugins.json` with additional `parent_plugin` (install
  pointer) + `tools` (trust-surface disclosure) fields. Built-in
  subagents and ai-kit's own subagents are explicitly excluded from
  the catalog — see `_meta.notes`.
- **Updated** `bin/lib/recommend-tools-lib.sh` — fourth `emit()` call
  for `subagents.json`, silent skip when absent (older clones). Sort
  key unchanged (score desc, kind, name).
- **Updated** `bin/recommend-tools.sh` — `--kind subagent` filter and
  usage doc.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — Extended
  section covers four catalogs (was three); trust-model bullet
  documents subagent-specific surface (parent_plugin install + tools
  list disclosure).
- **New** `bin/audit-setup-symmetry.sh` — enumerates
  `standards/external/*.json` and asserts each is wired via the
  scorer lib OR explicitly mentioned in `setup/SKILL.md`. Hard-coded
  exclusions: `plugins-excluded.json`, `VETTING.md`. Fails with
  pointer to #48 on mismatch.
- **Updated** `tests/bin/cases/apply-marker.sh` — 3 new assertions
  invoking `audit-setup-symmetry.sh`.
- **Updated** `tests/bin/cases/recommend.sh` — `kind` enum widened to
  `{mcp,hook,plugin,subagent}`; new assertion verifies
  `claude-code-guide` subagent surfaces and `--kind subagent` filter
  returns only subagent rows. 464/464 total pass (was 459).

The symmetry-audit lock means new catalogs added to
`standards/external/` MUST either be picked up by the scorer
(`emit()` call) or get their own setup branch — otherwise CI fails.
Closes the #48 DoD.

## 1.16.0 — 2026-05-25

Closes #19: `/ai:setup` now wires `/ai:recommend-tools` as a first-class
Tier-B branch (Branch 14), parallel to Branch 12 (rule recommendation).
Before: setup only mentioned `recommend-tools` as a one-liner at the
end — users had to know to re-invoke it. After: setup actively offers
to refine the companion-tool / MCP-server / Claude-Code-hook catalogs
against the detected stack.

Trust model unchanged — preview-then-confirm inside `recommend-tools`,
never auto-install. Brownfield with a detected framework defaults to
offering the branch; greenfield or stack-less projects default to
`skipped`.

Sets the pattern for #48 (setup-symmetry meta) — every
`standards/external/<category>.json` will eventually have a matching
Tier-B branch. #49 (recommend-plugins) and #50 (recommend-subagents)
follow this template once their catalog prerequisites land.

- **New** Branch 14 in `workflow/skills/setup/SKILL.md` — `[1] Refine now /
  [2] Later / [3] Keep default` prompt; defaults documented; marker
  key documented.
- **Updated** `bin/write-setup-marker.sh` — accepts
  `--tool-recommendation=completed|deferred|skipped`, writes
  `branches.tool_recommendation` in `.ai-kit-setup`.
- **Updated** `tests/bin/cases/apply-marker.sh` — 4 new assertions
  covering tool-recommendation absent-without-flag, round-trip, and
  preservation of sibling keys across re-writes. 39 total pass.
- **Removed** the orphan one-liner at the end of `setup/SKILL.md`
  that previously surfaced `recommend-tools` as a follow-up —
  superseded by Branch 14.

## 1.14.0 — 2026-05-23

Closes #32: new skill `audit-architecture` + canonical rule
`code-audit.mini.md`. Whole-codebase architecture-quality audit
against 9 dimensions, stack-agnostic, read-only, writes a severity-
tagged markdown report — fixing is a separate step.

Issue #32 proposed 8 dimensions. Reviewed the catalogue before
shipping:

- Folded "Comments/docs drift" into "Naming" (same intent-vs-text
  theme; standalone bucket was thin).
- Added "Error handling / failure modes" (swallowed exceptions,
  silent fallbacks, retry-without-backoff, race smells).
- Added "Type safety / contract clarity" (escape-hatch types,
  stringly-typed APIs, missing nullability, boolean-flag args).
- Sharpened the coupling-vs-layering separation: coupling is
  local/structural, layering is global/architectural.
- Rejected a "Testability" bucket — manifests as SOLID-DIP or
  coupling findings and would double-count.
- Explicitly out-of-scope: security (use `/ai:review` deep pass),
  performance, runtime profiling, pre-merge diff review.

Issue #32 options B (companion `audit-fix` skill) and C (per-stack
tuning extensions like `audit-architecture-laravel`) are deferred
to fresh follow-up issues — they need their own design and
shouldn't bloat v1.14.0.

- **New** `standards/rules/code-audit.mini.md` — frontmatter
  `universal: true`, `weight: medium`, `default_mode: on-demand`.
  Body covers the 9 dimensions, severity tagging (🔴/🟠/🟡/🟢),
  output contract (`docs/reviews/<date>-<scope>-architecture-audit.md`),
  and anti-patterns.
- **New** `workflow/skills/audit-architecture/SKILL.md` — invocable
  workflow. References the rule as the canonical catalogue. Delegates
  the codebase walk to the `explore` subagent on Claude Code; falls
  back to inline walk on hosts without subagents. Always read-only.
- **Updated** `tests/bin/cases/bootstrap-emit.sh` — `--list` count
  24 → 25, adds `code-audit listed` + source-file + `universal: true`
  assertions.
- **Updated** plugin manifest + README from 27 skills → 28 and
  24 rules → 25. README skill table gets a new `audit-architecture`
  entry under Cross-cutting.

## 1.13.0 — 2026-05-23

Closes #29: new canonical rule `domain-model-first`. Captures the
naschool 2026-05-23 "domain-model blindness" lesson from
`~/.claude/ai-kit-lessons.md` as a reusable, stack-agnostic primitive.
Ships universal so every `/ai:setup` run pulls it in.

The rule absorbs option C from the issue (verify-state generalisation)
as a sub-clause and skips option B (plan-mode gate) — that requires
harness changes ai-kit doesn't control.

- **New** `standards/rules/domain-model-first.mini.md` — frontmatter
  `universal: true`, `weight: high`, `default_mode: always-on`. Body
  covers when-the-gate-fires (architecture/schema verbs near domain
  nouns; entity names from CONTEXT.md; new-migration proposals),
  how-to-apply (locate canonical layer per-stack, read entity +
  related entities, verify don't assume, prefix proposal with
  evidence, prefer extending), when-to-skip (cosmetic / explicit
  user override / no-domain-layer), and a concrete anti-pattern
  using the naschool subsidy example.
- **Updated** `tests/bin/cases/bootstrap-emit.sh` — `--list` count
  23 → 24, adds `domain-model-first listed` assertion.
- **Updated** plugin manifest + README from 23 → 24 canonical rules.

Tests: 410 passed, 0 failed.

## 1.12.1 — 2026-05-23

Closes #24: surface `context7` more prominently in `/ai:recommend-tools`.
The pain was a closed framework signal-list — Phoenix repos, Go services,
Rust CLIs, niche stacks never saw the recommendation even though
context7's value (live docs vs. training-data hallucinations) is universal
for any project depending on third-party libraries.

- **Updated** `standards/external/mcp-servers.json` — context7 entry now
  carries `"universal": true`. The deterministic recommender's `universal`
  axis (already wired for hooks + plugins) now applies to MCP too, so
  context7 surfaces on every stack while keeping its framework/dependency
  boosts for ranking.
- **Updated** `workflow/skills/recommend-tools/SKILL.md` — companion
  table grows from three rows to four (graphify / caveman / llm-wiki /
  context7). Note clarifies context7 is the one universal companion.
- **Updated** `tests/bin/cases/recommend.sh` — empty-stack assertion
  inverted: was "no MCP recs", now "only context7 surfaces (universal),
  no stack-specific MCPs". Adds direct `name == "context7"` assertion.

No new primitives. Trust model unchanged (preview-then-confirm). Lands
ahead of #19's wider signal-table restructure; the additive
universal-flag pattern survives a future scorer refactor cleanly.

## 1.12.0 — 2026-05-23

New `/ai:onboard` skill wraps the harness `ShareOnboardingGuide` tool — drafts
a project-scoped `ONBOARDING.md` from existing artifacts (README, CONTEXT.md,
`.ai-kit-setup`, ADRs), confirms with the user, then publishes a short-link.
Composes with `/ai:handoff`: handoff = leaves a machine, onboard = arrives
at a project.

- **New** `workflow/skills/onboard/SKILL.md` — full template + audience
  scoping + idempotent re-run contract (refreshes the existing guide; same
  short-link keeps working).
- **New** `tests/eval/prompts/onboard/new-contractor-arriving.md` —
  eval-structure requires ≥1 fixture per skill.
- **Updated** count assertions: `structure.sh` (26→27 skills, adds onboard
  existence assertion), `release-install.sh` (`which --list`: 26→27).
- **Updated** plugin manifest + README + architecture/install/mental-model
  docs from 26 → 27 skills.

## 1.11.0 — 2026-05-23

`/ai:setup` now offers the v1.9.0 repo template pack as an optional Tier B
branch — per-file consent, default skip when a file already exists, no new
bin script (skill prompt drives a plain `cp`).

- **Updated** `workflow/skills/setup/SKILL.md` — adds Branch 13 "Repo
  templates" to the Tier B table, a full section with source/destination
  table + per-file copy contract, marker shape extension
  (`repo_templates: skipped|all|picked`), and the Done-step marker
  invocation now passes `--repo-templates=...`.
- **Updated** `bin/write-setup-marker.sh` — accepts
  `--repo-templates=all|picked|skipped` and persists it under
  `branches.repo_templates`. Backward-compatible: the flag is optional,
  marker JSON omits the field when not passed.

No new skills/commands/rules. Test count stays at 407.

## 1.10.2 — 2026-05-23

Regression-lock for v1.3.0–v1.10.0 surface changes. All tests green
(407 passed, 0 failed) on a fresh `tests/bin/run-all.sh`.

- **New test case** `tests/bin/cases/dedupe.sh` — 13 assertions covering
  `ai-kit-dedupe.sh` help / JSON shape / orphan rule detection /
  --fix-prints-but-doesn't-execute / unknown-flag rejection.
- **Updated** `tests/bin/cases/recommend.sh` — adds `--kind plugin`
  filter test, `laravel-boost` + `claude-mem` surface assertions,
  universal-plugin-on-empty-stack assertion. Adjusts the
  "kind in {mcp,hook}" assertion to include `plugin` (v1.8.0 surface
  change).
- **Updated** count assertions: `structure.sh` (23→26 skills, 7→8
  commands incl. new `dedupe` command), `release-install.sh`
  (`which --list`: 23→26), `bootstrap-emit.sh` (`emit-rules --list`:
  8→23).
- **New eval fixtures** for the three new skills:
  `tests/eval/prompts/{should-i-use,feedback,contribute-eval}/*.md`.
  Each fixture has frontmatter `expects[]` listing the testable
  behaviours, which the eval-structure check requires.
- **Plugin manifest** `workflow/.claude-plugin/plugin.json` description
  bumped to mention 26 skills / 8 commands / 23 rules / feedback loop
  + curated MCP/hook/plugin recommendations.

No surface or behaviour change in the skills/rules themselves.

## 1.10.1 — 2026-05-23

Docs sync — README + architecture + install-plugin + mental-model
all referenced stale counts from the v1.0 release (23 skills, 7
commands, 7 rule books). No surface or behaviour change.

Updated counts in README to current totals: 26 skills, 8 slash
commands, 23 canonical mini-rules, 21 MCP + 25 hooks + 12 plugins
curated, 5 repo templates. Added Feedback Loop section (`/ai:feedback`
+ `/ai:contribute-eval`). Pin-release example bumped to v1.10.0.

## 1.10.0 — 2026-05-23

Stack-specific micro-rules pack — 5 new rules gated on detected stack.

- `laravel-conventions.mini.md` — Eloquent, Form Requests, queues
  (idempotent + `WithoutOverlapping`), Artisan, multi-tenancy via Global
  Scope. Fires on `laravel` framework.
- `tailwind.mini.md` — utility-first discipline, tokens in `tailwind.config`
  not literals, `cn()`+`cva` patterns, mobile-first responsive order,
  `focus-visible:` over `focus:`. Fires on `tailwindcss`.
- `prisma.mini.md` — schema-first, narrow `include`/`select`, cursor
  pagination, explicit transactions, N+1 detection, no
  `$queryRawUnsafe`. Backend architecture.
- `react-rsc.mini.md` — Server Components by default, push `"use client"`
  down the tree, async data fetch in RSC, Server Actions for mutations,
  Suspense per independent slow region. Fires on `nextjs`/`remix`.
- `sql-style.mini.md` — UPPERCASE keywords, no `SELECT *`, explicit
  `INNER JOIN`, half-open date ranges, parameterised queries always,
  `RETURNING` for one-roundtrip writes.

All 5 use `universal: false` + framework/architecture signals so they
only score when the relevant stack is detected — keeps the universal
rule set lean for stack-agnostic repos.

Shipping surface at v1.10.0:

- 26 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- **23 canonical rules** (was 18) under `standards/rules/`
- 21 curated MCP servers + 25 curated hook recipes + 12 curated plugins
- 5 repo templates under `context/templates/repo/`

## 1.9.0 — 2026-05-23

Repo template pack — drop-in baseline files under
`context/templates/repo/`. Quick win, real toil saved per new repo.

Added templates:

- `.editorconfig` — charset, line endings, per-language indent overrides
  (Python 4, Go tabs, Markdown preserves trailing whitespace).
- `.gitattributes` — LF normalisation, binary markers, `-diff` on
  lockfiles.
- `CODEOWNERS` — empty template with examples for default, backend,
  frontend, infra, docs, and security-critical paths.
- `renovate.json` — Renovate Bot defaults: weekly cadence, dependency
  dashboard, semantic commits, auto-merge for non-major dev-deps,
  major bumps human-gated, GH Actions pinned to SHA.
- `.envrc` — direnv stub with commented hooks for Node/Python/PHP
  version pinning.
- `README.md` — what each file does and when to use it.

Templates are available now via `$AI_KIT_ROOT/context/templates/repo/`;
`/ai:setup` integration as an optional offer-step is queued for a
future minor (no skill change in this release).

Shipping surface at v1.9.0:

- 26 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes + 12 curated plugins
- **5 repo templates** under `context/templates/repo/`

## 1.8.0 — 2026-05-23

Complete the `recommend-tools` curation triad (MCP / hook / **plugin**).

- **New curation file** `standards/external/plugins.json` — 12 curated
  third-party Claude Code plugins with stack signals and one-line install
  commands:
  - `claude-mem`, `tdd-guard`, `ask-questions-if-underspecified`,
    `claude-md-management`, `skill-creator` — universal
  - `github`, `laravel-boost`, `frontend-design`, `lazyweb`,
    `chrome-devtools-mcp`, `typescript-lsp`, `php-lsp` — stack-gated
  Each entry includes `marketplace` and `install` fields so the skill
  can surface the exact `/plugin install <name>@<marketplace>` command
  without guessing.
- **Scorer extended** (`bin/lib/recommend-tools-lib.sh`,
  `bin/recommend-tools.sh`) — loads `plugins.json` (optional; older
  clones without the file skip silently), emits rows with
  `kind="plugin"`, accepts `--kind plugin` filter alongside existing
  `mcp` / `hook` / `all`.
- **Skill update** `recommend-tools` — documents the third surface,
  trust posture for plugin install ("never auto-install — show the
  `/plugin install` command, user pastes"), marketplace-registration
  caveat.

Smoke-tested against the ai-kit repo: scorer surfaces 5 plugins,
2 MCP servers, 7 hooks. `--kind plugin` filter works.

Shipping surface at v1.8.0:

- 26 skills (unchanged; 1 edited — recommend-tools)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes + **12 curated
  Claude Code plugins**

## 1.7.0 — 2026-05-23

Close the user feedback loop (Phase 2 of < 50-user feedback design).

- **New skill** `contribute-eval` (`workflow/skills/contribute-eval/`) —
  turns a skill failure into a regression test by composing a prompt
  fixture (`tests/eval/prompts/<skill>/<scenario>.md`) plus a golden
  rubric (`tests/eval/goldens/<skill>/<scenario>.md`) and opening a PR
  against `yusufkaracaburun/ai-kit`. Captures the verbatim prompt, the
  actual output, and the user's expected-behaviour bullets; derives
  rubric fields conservatively from those bullets (no invented
  `required_keywords`). Reuses the same redaction rules as
  `/ai:feedback` (paths, secrets, tenant names, emails). One case per
  PR; previews both files + full PR body before any write.

Motivation: `/ai:feedback` captures *that* something is wrong;
`/ai:contribute-eval` captures *what* would have been right and locks
it into CI. The two skills are a pair — feedback ⇒ triage ⇒
contribute-eval ⇒ PR ⇒ CI gate. Every contributed case becomes a
regression test the next release must pass.

Shipping surface at v1.7.0:

- 26 skills (was 25) — adds `contribute-eval`
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.6.0 — 2026-05-23

Open the user feedback loop (Phase 1 of < 50-user feedback design).

- **New skill** `feedback` (`workflow/skills/feedback/`) — walks the user
  through one structured piece of feedback (friction/surprise/clarity/
  gap/win), redacts absolute paths and secret-shaped strings from any
  context block, and opens a GitHub issue against `yusufkaracaburun/ai-kit`
  using the new `feedback.yml` template. Never publishes without showing
  the final body first.
- **New issue template** `.github/ISSUE_TEMPLATE/feedback.yml` — structured
  feedback form with kind dropdown, area multi-select, situation /
  friction / better fields, optional redacted-context block, redaction
  checkbox gates.
- **New issue config** `.github/ISSUE_TEMPLATE/config.yml` — disables
  blank issues, points open-ended chat to Discussions, keeps the issue
  tracker reserved for trackable work.

Motivation: at < 50 users, telemetry pipelines are premature; GitHub +
a guided capture skill is enough to compound user feedback into PRDs
via the existing `/ai:triage` → `/ai:to-prd` flow. Phase 2 (eval-loop
contributions) and Phase 3 (recommendation engine) deferred until
inflow justifies them.

Shipping surface at v1.6.0:

- 25 skills (was 24) — adds `feedback`
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (unchanged)
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.5.0 — 2026-05-23

Mini-rules pack — 8 new canonical rules under `standards/rules/`.

Universal (always-on, weight high/medium/low):

- `testing-pyramid.mini.md` — 70/25/5 unit/integration/E2E discipline,
  no flaky-retry-in-CI, bug fixes ship with regression tests.
- `error-handling.mini.md` — validate at boundaries, trust internal code,
  never swallow errors, throw vs return guidance.
- `observability.mini.md` — structured logs, RED/USE metrics, OpenTelemetry
  traces, cardinality discipline.
- `secrets-hygiene.mini.md` — never commit/log secrets, single secret store
  per env, rotation playbook, gitleaks in pre-commit + CI.
- `semver.mini.md` — MAJOR/MINOR/PATCH bump rules, deprecate-before-remove,
  CHANGELOG-in-same-commit discipline.

Stack-specific (fire on matching architecture):

- `a11y.mini.md` — WCAG 2.2 AA baseline for frontend stacks (react, vue,
  angular, nextjs, nuxt, svelte, remix, astro).
- `api-design.mini.md` — REST conventions, status codes, OpenAPI as source of
  truth for backend frameworks (express, fastify, nestjs, fastapi, django,
  rails, laravel, spring).
- `twelve-factor.mini.md` — 12factor.net discipline for backend services.

Smoke-tested against the ai-kit repo: 6/8 new rules score in
`recommend-rules.sh --json` (universal ones); stack-specific 3 require
frontend/backend detection to score, working as designed.

Shipping surface at v1.5.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 18 canonical rules (was 10) under `standards/rules/`
- 21 curated MCP servers + 25 curated hook recipes (unchanged)

## 1.4.1 — 2026-05-23

Drop `notion`, `figma`, `mongodb` from MCP curation per maintainer
decision — narrowing recommend-tools surface to servers we actively use
or actively recommend. MCP count: 24 → 21.

## 1.4.0 — 2026-05-23

Expand `recommend-tools` curation with 9 MCP servers and 9 hook recipes.
Pure data — no scorer or skill changes.

**MCP additions (`standards/external/mcp-servers.json` 15 → 24):**

- `obsidian` — Obsidian vaults (`.obsidian/`)
- `notion` — Notion docs/PRDs/roadmap (`@notionhq/client`, `notion-sdk-py`)
- `figma` — Frontend with Figma design files (`figma-api`, `figma-export`)
- `stripe` — Payments/subscriptions (`stripe`, `stripe/stripe-php`)
- `mongodb` — Direct MongoDB access (`mongoose`, `pymongo`)
- `redis` — Cache/queue/pubsub (`redis`, `ioredis`, `predis/predis`)
- `mysql` — Direct MySQL/MariaDB access (`mysql2`, `pymysql`)
- `firecrawl` — Web scraping / doc ingestion (`firecrawl-py`)
- `exa` — Semantic web search (`exa-py`, `exa-js`)

**Hook additions (`standards/external/hooks-patterns.json` 16 → 25):**

- `phpstan` (PHP static analysis) — `phpstan.neon`
- `cargo-clippy` (Rust lint) — `Cargo.toml`
- `swift-format` (Apple swift-format) — `Package.swift`
- `dart-format` (Dart/Flutter) — `pubspec.yaml`
- `commitlint` (Conventional Commits enforcement) — `commitlint.config.*`
- `gitleaks-scan` (block secrets on write) — universal
- `branch-guard` (warn/block edits on protected branch) — universal
- `large-diff-warn` (surface big single-edit warnings) — universal
- `pre-commit-run` (reuse project's pre-commit framework) — `.pre-commit-config.yaml`

Motivation: `recommend-tools` scorer already consumes both JSON files; adding
entries instantly widens stack coverage without touching any code path.

Shipping surface at v1.4.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (unchanged)
- 10 canonical rules (unchanged)
- 24 curated MCP servers + 25 curated hook recipes

## 1.3.0 — 2026-05-23

Add duplication detection for safer plugin updates.

- **New slash command** `/ai:dedupe` — scans four surfaces and reports
  duplicates/orphans without ever deleting:
  1. Personal skills (`~/.claude/skills/`) shadowing plugin skills.
  2. Personal agents (`~/.claude/agents/`) shadowing plugin agents.
  3. Orphan emitted rules (`.cursor/rules/ai-kit-*.mdc`) whose canonical
     source no longer exists in the plugin (stale after rule rename/removal).
  4. Hook overlap in project `.claude/settings.json`.
- **New bin script** `bin/ai-kit-dedupe.sh` — supports `--json` and `--fix`
  (prints suggested `rm` commands, never executes). Exit 0 = clean, 1 = dups.
  Mirrored to `workflow/bin/` so it ships in the plugin.

Motivation: every `/plugin update` risks personal-skill shadowing and orphan
emitted rules accumulating silently. `/ai:dedupe` surfaces them on demand
without auto-deleting anything — user always reviews the cleanup commands
before running them.

Shipping surface at v1.3.0:

- 24 skills (unchanged)
- 3 subagents (unchanged)
- 8 slash commands (was 7) — adds `/ai:dedupe`
- 10 canonical rules (unchanged)

## 1.2.0 — 2026-05-23

Codify "grill before plan" — prevent agents from jumping straight to plan
or implementation when handed an issue/PRD/spec that *looks* complete.

- **New rule** `grill-first.mini.md` (`standards/rules/`) — universal, high
  weight. Specifies when the grill gate fires, the minimum question set
  (scope split, detection logic, override pattern, bundle-vs-defer, data
  contract), routing to `grill-with-docs` vs `grill-me`, and when to skip.
- **Skill update** `to-issues` — inserts a 1.5 Grill-first gate between
  "Gather context" and "Explore the codebase", with explicit reference to
  the new rule.
- **Skill update** `tdd` — adds grill-first as a precondition before the
  first failing test, alongside the existing `context-discipline` link.

Motivation: Issue bodies, PRDs, and memory anchors look deterministic but
are almost always under-specified. Discovering that mid-plan = wasted
context. Discovering it pre-plan = cheap. Prevention beats cure.

Shipping surface at v1.2.0:

- 24 skills (unchanged; 2 edited)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 10 canonical rules (was 9) under `standards/rules/`

## 1.1.0 — 2026-05-23

Surface expansion from personal `~/.claude/` companions.

- **New skill** `should-i-use` (`workflow/skills/should-i-use/`) — structured
  vendor / wire / adopt / ignore verdict for any candidate tool, repo, URL, or
  pasted artifact. Critical-advisor variant of `/ai:triage` for inbound tooling.
- **New rule** `context7.mini.md` (`standards/rules/`) — canonical
  ctx7 CLI usage guidance. Pairs with the existing `context7` MCP entry in
  `standards/external/mcp-servers.json` to close the docs-lookup loop.

Shipping surface at v1.1.0:

- 24 skills (was 23)
- 3 subagents (unchanged)
- 7 slash commands (unchanged)
- 9 canonical rules (was 8) under `standards/rules/`

## 1.0.0 — 2026-05-23

Initial release after version-history reset. Prior tags (v1.0.0–v5.0.2)
were deleted from origin on 2026-05-23 to consolidate the rapid pre-1.0
churn that accumulated during the May 2026 primitive-expansion + plugin
distribution work. Git history of `master` is preserved — only version
tags + this CHANGELOG were reset.

Current shipping surface at v1.0.0:

- 23 skills (workflow/skills/)
- 3 subagents (workflow/agents/)
- 7 slash commands (workflow/commands/)
- Self-contained Claude Code plugin distribution (workflow/bin/, workflow/hooks/)
- Cursor + Claude Code rule emitters (bin/lib/emitters/{cursor,claude-code,generic}.sh)
- 387-test regression suite
