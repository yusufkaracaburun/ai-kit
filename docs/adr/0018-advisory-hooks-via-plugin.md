# ADR-0018: Advisory hooks ship through the plugin, gated on the marker

## Status

Accepted 2026-10-10 (grilled, #205). Supersedes the install half of ADR-0005;
follows the delivery model of ADR-0015 and the gated hook of ADR-0017.

## Context

`/ai:setup` copied four hooks (search-delegation, build-delegation,
phase-check, context-drift) into `<project>/.claude/hooks/` and wired them in
the project's `settings.json`. `/ai:upgrade` never refreshed those copies, so
a hook fix in a new plugin release reached a project only when `/ai:setup`
ran again. Doctor could detect the drift with `cmp` but not fix it.

## Decision

1. The four hooks ship in `workflow/hooks/hooks.json`, at the events and
   matchers the old appliers wired. `bin/sync-plugin-hooks.sh` keeps the
   bundled copies byte-identical to `bin/hooks/`.
2. Each hook gates itself on the project's `.ai-kit-setup` through
   `marker_hook_on` in `bin/lib/setup-marker.sh`. No marker: silent.
   search-delegation, build-delegation and phase-check fire unless
   `branches.<name>_hook` is `skipped`; context-drift stays opt-in and fires
   only on `wired`.
3. `/ai:setup` records the choice in the marker and copies nothing. The four
   `apply-*-hook.sh` scripts and `install_project_hook` are gone.
4. `/ai:upgrade` deletes the old project copies and their `settings.json`
   entries through `unwire_hook`. Doctor warns while a stale copy remains.

## Consequences

- A hook fix reaches every project with the next `/plugin update`.
- Projects without a marker get none of the four hooks, including ones that
  wired a hook by hand without running `/ai:setup`.
- Every gated hook call reads the marker with `python3`: phase-check on a
  silent prompt went from 19 ms to 43 ms per call (10-run loop, 2026-10-10).
- An inline graphify-only nudge from an old `/ai:recommend-tools` is no longer
  migrated automatically; the setup skill says to remove it by hand.
