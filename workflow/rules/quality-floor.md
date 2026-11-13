---
paths: ["**/*.sh", "**/*.bash", "**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.php", "**/*.dart", "**/*.py", "**/*.vue", "**/*.astro", "**/*.svelte", "**/*.go", "**/*.rs", "**/*.swift", "**/*.kt", "**/*.rb", "**/*.sql"]
---
<!-- ai-kit global rule (ADR-0015): Design checks every diff must pass, each a yes/no test; SOLID, DRY, YAGNI, deep modules, nearest-sibling parity -->
<!-- Source: standards/rules/quality-floor.mini.md — re-stamp with bin/sync-plugin-rules.sh -->


# Quality floor

The minimum a diff must meet before review calls it done. Each item is a
yes/no test a builder runs before reporting and a reviewer runs on the
diff. Cite a finding as `quality-floor: <section>`.

**Severity.** A failed check is a Blocker unless the diff or the report states a reason for it; with a stated reason it is a Suggestion.

## SOLID, DRY, YAGNI

- **Single responsibility.** Can you name what the changed class or function
  does in one sentence without "and"? No → split it or say why not.
- **Open/closed.** Does adding a case mean editing a growing `switch` or
  `if` chain in more than one place? Yes → finding.
- **Dependency direction.** Does domain code import a framework, HTTP or
  storage type it could take as a parameter? Yes → finding.
- **DRY.** Is the same rule (validation, mapping, formula) now written in
  two places? Yes → finding. Similar-looking code that changes for
  different reasons is not duplication.
- **YAGNI.** Does the diff add a flag, option, interface or parameter that
  no current caller uses? Yes → finding.

## Deep modules

- **No pass-through.** Does a new method, service or layer only forward
  its arguments to one other call? Yes → finding.
- **Interface smaller than the body.** Must callers know the call order,
  a mode flag or the storage shape to use it? Yes → finding.

## Pre-write gates

The four gates in `pre-write-discipline` apply; a failed gate is a finding.

## Nearest shape and sibling parity

- **Name the sibling.** For a new screen, module, endpoint or test, name
  the nearest existing one of the same kind. None exists → say so.
- **Same pattern.** Does the new code follow the sibling's file layout,
  naming, layering, error handling, state handling and test placement?
- **Deviation needs a reason.** Each deviation from the sibling is a
  finding; its severity follows the Severity line above.

## See also
[`pre-write-discipline`](./pre-write-discipline.md) (the four gates), `aposd.mini.md` (deep modules in full), `code-audit.mini.md` (stack audits).
