#!/usr/bin/env python3
# Parse the frontmatter of an audit-architecture-* SKILL.md.
# Stdout:
#   EXTENDS=<value or empty>
#   FRAMEWORKS=<comma-joined>
#   LANGUAGES=<comma-joined>
# Exit 0 always; downstream interprets missing fields.
#
# Supports two YAML list shapes for applies_to.{frameworks,languages}:
#   1) inline: `frameworks: ["laravel", "react"]`
#   2) block:  `frameworks:\n  - laravel\n  - react`

import pathlib
import re
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("EXTENDS=")
        print("FRAMEWORKS=")
        return 0

    path = pathlib.Path(sys.argv[1])
    try:
        text = path.read_text()
    except OSError:
        print("EXTENDS=")
        print("FRAMEWORKS=")
        return 0

    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        print("EXTENDS=")
        print("FRAMEWORKS=")
        return 0

    fm = m.group(1)
    extends = ""
    frameworks: list[str] = []
    languages: list[str] = []
    in_applies = False
    active_list: list[str] | None = None  # which list block-form items append to

    def parse_inline_list(rest: str) -> list[str]:
        if rest.startswith("[") and rest.endswith("]"):
            inner = rest[1:-1].strip()
            if not inner:
                return []
            return [
                p.strip().strip('"').strip("'")
                for p in inner.split(",")
                if p.strip()
            ]
        return []

    for raw in fm.splitlines():
        line = raw.rstrip()
        if not line:
            active_list = None
            continue
        if line.startswith("extends:"):
            extends = line.split(":", 1)[1].strip().strip('"').strip("'")
            active_list = None
        elif line.startswith("applies_to:"):
            in_applies = True
            active_list = None
        elif in_applies and line.lstrip().startswith("frameworks:"):
            rest = line.split(":", 1)[1].strip()
            if rest:
                frameworks = parse_inline_list(rest)
                active_list = None
            else:
                active_list = frameworks
        elif in_applies and line.lstrip().startswith("languages:"):
            rest = line.split(":", 1)[1].strip()
            if rest:
                languages = parse_inline_list(rest)
                active_list = None
            else:
                active_list = languages
        elif active_list is not None and line.lstrip().startswith("- "):
            value = line.lstrip()[2:].strip().strip('"').strip("'")
            if value:
                active_list.append(value)
        elif not line.startswith(" "):
            in_applies = False
            active_list = None

    print(f"EXTENDS={extends}")
    print(f"FRAMEWORKS={','.join(frameworks)}")
    print(f"LANGUAGES={','.join(languages)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
