# ADR-0020: Paper replaces Pencil

## Status

Accepted (2026-10-29). Tracked in #258 and #259. Supersedes the Pencil line in
[ADR-0013](0013-agents-need-a-nudge.md) (decision 5) and the
`mcp__pencil__execute` entry in the lead-guard list of
[ADR-0017](0017-lead-contract.md).

## Context

Yusuf decided on 2026-10-29: "ik ga geen pencil meer gebruiken, want paper
vervangt alles". emeq-reui ran the Paper trial first and recorded the same
choice in its `docs/adr/0002-code-als-ontwerpbron.md`: "Paper vervangt Pencil
volledig."

The lead-guard hook denied `mcp__pencil__execute` for a lead session. With
Pencil gone that entry guards nothing, and Paper writes passed the guard.

## Decision

1. Paper is the design tool in every project. ai-kit keeps no Pencil support
   next to it and no design-tool abstraction.
2. Existing `.pen` files stay as a read-only archive. Nobody edits them.
3. Paper MCP tools run under the prefix `mcp__paper__`, as the emeq-reui
   sessions call them (`mcp__paper__write_html`, `mcp__paper__get_screenshot`).
4. The split between read and write follows the annotations the Paper MCP
   server reports itself. Source: `tools/list` on `paper mcp`
   (`paper-desktop` 0.0.1, 37 tools) on 2026-10-29.
   - Write (`destructiveHint`): `create_file`, `rename_resource`,
     `create_page`, `update_pages`, `arrange_pages`,
     `set_comment_thread_status`, `write_html`, `create_artboard`,
     `delete_nodes`, `set_text_content`, `rename_nodes`, `update_styles`,
     `duplicate_nodes`, `move_nodes`, `create_tokens`, `set_tokens`.
   - Read (`readOnlyHint`): every other tool, among them `get_basic_info`,
     `get_screenshot`, `get_computed_styles`, `get_jsx`, `get_tokens`,
     `open_file`, `export` and `finish_working_on_nodes`.
   The emeq-reui trial log (`docs/poc/paper-proef-log.md`) shows the same
   tools in use, for example "| 8 | write_html | whole screen in one call" and
   "| 9 | get_screenshot | review 1: week nav 8pt too high".
5. lead-guard denies the 16 write tools for a `role=lead` session and names
   Paper and `ai:designer` in the deny message. Read tools stay silent. The
   `hooks.json` PreToolUse matcher lists the same 16 tools and no longer
   lists `mcp__pencil__execute`.

## Consequences

- A lead that edits a Paper design inline gets denied and hands the edit to
  `ai:designer`.
- `export` writes a PNG to `~/Downloads` but counts as a read, because the
  server marks it read-only and it does not change the design.
- A new Paper write tool passes the guard until someone adds it to the hook
  and the matcher. Check `tools/list` when Paper updates.
- The guard assumes Paper runs as the MCP server `paper`. Installed through a
  plugin, the tools get names like `mcp__plugin_<x>_paper__write_html` and
  pass the guard.
