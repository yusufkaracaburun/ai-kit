#!/usr/bin/env bash
# ai-kit-tick-dod.sh: tick proven checkboxes on one issue, and nothing else.
#
# The boxes file holds one box text per line, exactly as it stands after "- [ ] ".
# Only boxes under Acceptance criteria, Done when / Klaar wanneer and Definition of
# Done count, at any heading level from ##; fenced code does not count. Nothing is
# written when a listed box is not there, when a text stands on the card a different
# number of times than it is listed, or when the body changed while this ran.
# Prints every box in those sections that stays open as "open: <text>".
#
# Exit codes: 0 done, 1 refused or gh failed (nothing ticked), 2 bad arguments.
#
# Usage: ai-kit-tick-dod.sh <issue-number|issue-url> <boxes-file>
#
set -euo pipefail

if [ $# -ne 2 ] || [[ "$1" == -* ]] || [ ! -f "$2" ]; then
  echo "Usage: $0 <issue-number|issue-url> <boxes-file>" >&2
  exit 2
fi

exec python3 - "$1" "$2" <<'PY'
import collections, json, re, subprocess, sys, tempfile

issue, boxes_file = sys.argv[1:]
HEADING = re.compile(r" {0,3}(#{1,6})\s")
FENCE = re.compile(r"\s*(`{3,}(?=[^`]*$)|~{3,})(.*)")
SECTION = re.compile(r"\s*##+\s+(acceptance criteria|acceptatiecriteria|done when|klaar wanneer|definition of done)\b", re.I)
# Same line shape as dor-dod-enforcement.yml.
BOX = re.compile(r"\s*-\s*\[([ xX])\]\s*(.+)")


def refuse(*reasons):
    for reason in reasons:
        print(f"tick-dod: {reason}", file=sys.stderr)
    print(f"tick-dod: #{issue} not changed", file=sys.stderr)
    sys.exit(1)


def gh(*args):
    run = subprocess.run(["gh", "issue", *args], capture_output=True, encoding="utf-8")
    if run.returncode:
        refuse(f"gh issue {args[0]} failed: {run.stderr.strip()}")
    return run.stdout


def read_body():
    return json.loads(gh("view", issue, "--json", "body"))["body"] or ""


with open(boxes_file, encoding="utf-8") as f:
    listed = collections.Counter(line.strip() for line in f if line.strip())

before = read_body()
lines = before.split("\n")
boxes = []  # (line index, match)
level = 0  # heading level of the counted section, 0 outside one
fence = ""
for i, line in enumerate(lines):
    line = line.rstrip("\r")
    marker = FENCE.match(line)
    if fence:
        if marker and marker[1].startswith(fence) and not marker[2].strip():
            fence = ""
        continue
    if marker:
        fence = marker[1]
        continue
    heading = HEADING.match(line)
    if heading and (not level or len(heading[1]) <= level):
        level = len(heading[1]) if SECTION.match(line) else 0
    match = BOX.match(line)
    if level and match:
        boxes.append((i, match))

found = collections.Counter(m[2].strip() for _, m in boxes)
problems = [f"not on the card: {text}" for text in listed if not found[text]]
problems += [
    f"on the card {found[text]} times, listed {count}: {text}"
    for text, count in listed.items()
    if found[text] and found[text] != count
]
if problems:
    refuse(*problems)

ticked, still_open = 0, []
for i, match in boxes:
    text = match[2].strip()
    if match[1] != " ":
        continue
    if text in listed:
        lines[i] = lines[i][: match.start(1)] + "x" + lines[i][match.end(1) :]
        ticked += 1
    else:
        still_open.append(text)

if ticked:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", suffix=".md") as out:
        out.write("\n".join(lines))
        out.flush()
        # shortcut: an edit landing between this read and the write is lost; the API has no conditional update.
        if read_body() != before:
            refuse("the body changed while ticking, run again")
        gh("edit", issue, "--body-file", out.name)
print(f"tick-dod: #{issue} ticked {ticked}")
for text in still_open:
    print(f"open: {text}")
PY
