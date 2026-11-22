#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== vetting-trial ==="
# A positive audit row (VERDICT: ADD or VENDOR) in VETTING.md needs a TRIAL
# line with every trial field, or the one-off `legacy, unmeasured` marker.

# Prints the first line of every positive audit block without a valid TRIAL.
missing_trial() {
  awk '
    /^```/ {
      if (inblk && pos && !ok) print head
      inblk = !inblk; head = ""; pos = 0; ok = 0; trial = ""; intrial = 0; next
    }
    !inblk { next }
    head == "" { head = $0 }
    /^  [A-Z][A-Z-]*:/ { intrial = 0 }
    tolower($0) ~ /^  verdict[^:]*:[[:space:]]*(add|vendor|wire|adopt)/ { pos = 1 }
    /^  TRIAL:/ { intrial = 1 }
    intrial {
      trial = trial " " $0
      if (trial ~ /legacy, unmeasured/) ok = 1
      n = split("repo= task= metric= baseline= result= date= re-measure=", k, " ")
      all = 1
      for (i = 1; i <= n; i++) if (index(trial, k[i]) == 0) all = 0
      if (all) ok = 1
    }
  ' "$1"
}

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

cat > "$T/no-trial.md" <<'EOF'
```
bare · category=x · added 2026-11-21
  LICENSE:          MIT + safe
  VERDICT:          ADD (wired)
```
EOF
cat > "$T/partial.md" <<'EOF'
```
half · category=x · added 2026-11-21
  TRIAL:            repo=demo-app task=nav metric=loc
  VERDICT:          ADD (wired)
```
EOF
cat > "$T/ok.md" <<'EOF'
```
legacy · category=x · added 2026-05-23
  TRIAL:            legacy, unmeasured
  VERDICT:          VENDOR
```

```
measured · category=x · added 2026-11-21
  TRIAL:            repo=demo-app task=nav-drawer metric=loc baseline=120
                    result=40 date=2026-11-21 re-measure=2026-12-05
  VERDICT:          ADD (wired)
```

```
rejected · category=x · added 2026-11-21
  VERDICT:          REJECT (licence)
```
EOF

assert "positive row without TRIAL is flagged" \
  '[ "$(missing_trial "$T/no-trial.md")" = "bare · category=x · added 2026-11-21" ]'
assert "positive row with partial TRIAL is flagged" \
  '[ -n "$(missing_trial "$T/partial.md")" ]'
assert "legacy, full TRIAL and REJECT rows pass" \
  '[ -z "$(missing_trial "$T/ok.md")" ]'
assert "every positive row in VETTING.md carries a TRIAL line" \
  '[ -z "$(missing_trial "$AIKIT/standards/external/VETTING.md")" ]'

# A reversed Ignore whose `now` is positive is a positive record too.
reversed_without_trial() {
  jq -r '.reversed[] | select(.now | test("^(Wire|Vendor|Adopt|Merge)")) | select(has("trial") | not) | .name' "$1"
}
cat > "$T/reversed.json" <<'EOF'
{"reversed": [
  {"name": "bare", "now": "Wire. companions.json"},
  {"name": "legacy", "now": "Adopt as pattern", "trial": "legacy, unmeasured"},
  {"name": "still-out", "now": "Ignore, reconfirmed"}
]}
EOF
assert "reversed positive entry without trial is flagged" \
  '[ "$(reversed_without_trial "$T/reversed.json")" = "bare" ]'
assert "every positive reversed entry in plugins-excluded.json carries a trial" \
  '[ -z "$(reversed_without_trial "$AIKIT/standards/external/plugins-excluded.json")" ]'

print_summary_and_exit
