## ponytail (minimal-code discipline)

[ponytail](https://github.com/DietrichGebert/ponytail) constrains what the agent
**builds**. Before writing code it walks a YAGNI ladder: does this need to exist →
is it already in the codebase → does the stdlib cover it → does the platform cover
it natively → only then a dependency → can it be one line → otherwise the minimum
that works.

- `/ai:setup` **asks** before installing it (Branch 2e, default yes). It is never
  enabled behind your back, and never installed silently.
- Activation is **machine-wide**: it changes how the agent writes code in every
  project on this machine, not only this one.
- Switch level with `/ponytail lite|full|ultra`; `/ponytail off` for the session,
  `bin/apply-ponytail.sh --uninstall` to remove it.
- **Security, validation, error handling and accessibility are out of scope for the
  cut** — ponytail shortens code, it does not thin safety.
- It injects at `SessionStart` and at `SubagentStart`, so subagents that write code
  (builder, designer, debugger) inherit the same discipline instead of drifting
  back to over-building.

### With caveman

The two are orthogonal and are meant to run together. caveman compresses what the
agent *says*; ponytail constrains what it *builds*. caveman leaves code
byte-for-byte exact, ponytail stays out of the prose.

### With `pre-write-discipline`

Same discipline, different delivery. ai-kit's `pre-write-discipline.mini.md` is the
readable, on-demand version of the rule; ponytail is the enforced always-on one.
The rule dropped to `default_mode: on-demand` when ponytail landed, so there is one
always-on source rather than two competing ones.
