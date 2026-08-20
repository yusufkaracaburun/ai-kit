#!/usr/bin/env bash
# Report secrets already committed to a project's git history.
#
# This is the moment a PreToolUse write-guard cannot see. A guard on
# Edit|Write inspects what an agent is about to write; every finding that
# matters is usually already in a commit. A sweep over six real projects
# returned 104 findings and not one of them post-dated the sweep.
#
# Three properties are load-bearing:
#
#   Redacted. The report travels into agent context, so it carries paths,
#   line numbers, rule ids and entropy — never a value. gitleaks runs with
#   --redact and the report file lands outside the scanned project.
#
#   Ranked, never filtered. Everything stays reachable. A quality filter on
#   rule id would have discarded the rule that misfires on serialized blob
#   data — which is exactly what surfaced database dumps committed to a real
#   repo. So the tail is collapsed, not dropped.
#
#   Grouped by file, ordered by entropy. 104 findings collapsed to ~25
#   files; the raw count is itself noise. Entropy ordering floats a real
#   private key above a public-by-design client id without a hand-kept
#   rule-quality table that would drift as gitleaks changes its rules.
#
# No baseline, ever. --baseline-path on a first run records the findings
# this exists to surface as already accepted.
set -uo pipefail

usage() {
  echo "Usage: $0 /path/to/project"
  exit 1
}

[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac

TARGET="$(cd "$1" 2>/dev/null && pwd)" || {
  echo "Not a directory: $1" >&2
  exit 1
}

# Tool gate. Absence is never fatal — the same contract every other external
# tool in this kit follows. gitleaks is a Go binary: there is no npx path and
# vendoring it is not on the table, so a machine without it gets a visible
# skip rather than a failure that blocks whatever called us.
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "secrets-scan: gitleaks not on PATH — skipped."
  echo "  Install it (brew install gitleaks) to scan history for committed secrets."
  exit 0
fi

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "secrets-scan: $TARGET is not a git repository — nothing to scan."
  exit 0
fi

# Report goes to a temp path, never inside the project: the scan must not
# leave an artefact behind, least of all one holding findings.
REPORT="$(mktemp -t aikit-secrets-XXXXXX)"
GL_ERR="$(mktemp -t aikit-secrets-err-XXXXXX)"
trap 'rm -f "$REPORT" "$GL_ERR"' EXIT

(cd "$TARGET" && gitleaks detect --no-banner --redact \
  --report-format json --report-path "$REPORT") >/dev/null 2>"$GL_ERR"
GL_RC=$?

# gitleaks exits 0 for a clean scan and 1 when it found something. Anything
# else means the scan did not happen — a bad config, an unreadable object,
# a resource limit. That is an UNKNOWN result, and reporting it as "no
# findings" would hand back false assurance about secrets, which is a worse
# outcome than any leak this tool is meant to surface. Distinct exit code so
# a caller can tell "clean" (0) from "found" (1) from "did not run" (2).
if [ "$GL_RC" -ne 0 ] && [ "$GL_RC" -ne 1 ]; then
  echo "secrets-scan: gitleaks failed (exit $GL_RC) — result is UNKNOWN, not clean." >&2
  sed 's/^/    /' "$GL_ERR" >&2
  exit 2
fi

[ -s "$REPORT" ] || {
  echo "secrets-scan: no findings in $(basename "$TARGET")."
  exit 0
}

python3 - "$REPORT" "$TARGET" <<'PY'
import json, os, re, sys

report, target = sys.argv[1], sys.argv[2]

try:
    findings = json.load(open(report))
except Exception:
    findings = []

if not findings:
    print(f"secrets-scan: no findings in {os.path.basename(target)}.")
    raise SystemExit(0)

# A specific rule id is evidence; the generic catch-all is a hint. In the
# six-project sweep the generic rule produced 61 of 104 findings and almost
# all of the noise, while every confirmed leak carried a named rule.
GENERIC = "generic-api-key"

# A named rule inside a test asset is still a test asset. Promoting a
# fixture private key trains the reader to scroll past the tier that
# matters, which is the failure this tiering exists to prevent.
FIXTURE = re.compile(r"(^|/)(tests?|spec|fixtures?|examples?|samples?)(/|$)|\.example($|\.)", re.I)


def entropy(f):
    return float(f.get("Entropy") or 0.0)


by_file = {}
for f in findings:
    path = f.get("File", "")
    rec = by_file.setdefault(path, {"rules": set(), "n": 0, "entropy": 0.0, "lines": set()})
    rec["rules"].add(f.get("RuleID", "?"))
    rec["n"] += 1
    rec["entropy"] = max(rec["entropy"], entropy(f))
    if f.get("StartLine"):
        rec["lines"].add(f["StartLine"])

high, low = [], []
for path, rec in by_file.items():
    named = [r for r in rec["rules"] if r != GENERIC]
    if named and not FIXTURE.search(path):
        high.append((path, rec))
    else:
        low.append((path, rec))

high.sort(key=lambda kv: kv[1]["entropy"], reverse=True)

print(f"secrets-scan: {len(findings)} findings across {len(by_file)} files in {os.path.basename(target)}")
print()
print("  HIGH SIGNAL — named rule, outside test and example paths")
if high:
    for path, rec in high:
        rules = ", ".join(sorted(rec["rules"]))
        lines = ",".join(str(n) for n in sorted(rec["lines"])[:4])
        print(f"    {path}:{lines}  [{rules}]  entropy {rec['entropy']:.2f}  ({rec['n']}x)")
else:
    print("    none")
print()

low_n = sum(rec["n"] for _, rec in low)
if low_n:
    rules = sorted({r for _, rec in low for r in rec["rules"]})
    head = GENERIC if GENERIC in rules else rules[0]
    print(f"  LOW SIGNAL — {low_n} more in {len(low)} files, mostly {head}")
    print(f"    Nothing is hidden: cd {target} && gitleaks detect --redact  lists every one.")
    print()

if high:
    print("  Rotate first, then rewrite history. Rewriting alone leaves the")
    print("  credential compromised — assume anything ever committed has leaked.")

raise SystemExit(1 if high else 0)
PY
