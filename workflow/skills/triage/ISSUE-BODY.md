# Issue bodies

Every skill that creates an issue takes the body shape from the repo's own templates, `.github/ISSUE_TEMPLATE/*.md`. House style in older issues never overrides a template.

1. **Pick the type.** An epic or its PRD: `epic.md`. One deliverable piece: `story.md`. Small maintenance without a story: `task.md`. A fault: `bug.md`. Time-boxed research or a proof of concept: `spike.md`. Something not decided or not started: `idea.md`; picked up, it becomes a story, task, bug or spike. A known fault is always `bug.md`, also when it waits: waiting is the Backlog column, not a card kind. A subtask is a checkbox in its story; it becomes its own sub-issue (`task.md`) only when it ships separately or another executor takes it.
2. **Read that file and follow it.** Keep every `##` heading with its text, order and language, replace the placeholders. The frontmatter stays out of the body; the frontmatter labels and title prefix are applied with `--label` and in `--title` (a label the repo lacks is dropped, with a message, and its `--label` flag is left out). Extra headings go after the template's own. A story hangs under its epic as a GitHub sub-issue (`--parent <epic>`); an epic body never lists its stories. Tick a Definition of Ready box only when it holds; leave the Definition of Done boxes open.
   - The repo has `.md` templates but not this type: use the closest one it has. An idea uses the kit's `idea.md` plus the line `<!-- card: other -->`, only in this case.
   - The repo has no `.md` template: use the kit's file in `${CLAUDE_PLUGIN_ROOT:-$HOME/.config/ai-kit/plugin-current}/context/templates/github/ISSUE_TEMPLATE/`, `<type>.md` for Dutch issues and `<type>.en.md` for English.
3. **Untemplated cards.** The exploratory-test parent and the `/ai:setup` secrets-scan report keep their own shape and carry the line `<!-- card: other -->`.
4. **Post it.** Write the body to a file and pass its literal path: `gh issue create --title "<title>" --label "<label>" --body-file <path>`. No shell variable or command substitution in the path, no inline `--body`.

## Provable checkboxes

Every checkbox (acceptance criteria, Definition of Ready, Definition of Done, done when, the brief's criteria) is specific, measurable and relevant: one observable result plus how it is proven. No deadline per box; time lives on the board. Rewrite a criterion without a proof before the card is published.

Good: `- [ ] An expired token gets a 401 (proof: test "rejects an expired token")`
Bad: `- [ ] Auth works well`

A story also follows INVEST. Its Definition of Ready proves independent, small and testable. While writing, check that it gives someone a result they can name, that its diff can be estimated, and that the scope leaves the how open.
