# Issue tracker: Local Markdown

Issues and PRDs for this repo live as markdown files in `.scratch/`.

## Conventions

- One epic per directory: `.scratch/<epic-slug>/`
- The PRD is `.scratch/<epic-slug>/PRD.md`
- Stories are `.scratch/<epic-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<epic-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant issue"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.
