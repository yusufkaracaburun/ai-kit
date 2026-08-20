#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== secrets-scan ==="
# The scan reports what is already in a repo's history — the failure mode a
# PreToolUse write-guard cannot see. Its output enters agent context, so it
# carries paths, rule ids and entropy and never a value. Findings are ranked,
# never filtered: a specific rule in a real path is high signal, the generic
# catch-all and specific-rules-in-fixture-paths collapse into a count line.
# No baseline is ever written — baselining a discovery scan on first run
# records the very findings it exists to surface as already accepted.

SCAN="$AIKIT/bin/ai-kit-secrets-scan.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- fixture: one high-signal finding, one specific rule demoted by its
# --- path, and generic-rule noise for the collapsed tail.
P="$TMP/proj"
mkdir -p "$P/src" "$P/tests/fixtures"
git -C "$P" init -q 2>/dev/null || { mkdir -p "$P" && git -C "$P" init -q; }
git -C "$P" config user.email test@example.invalid
git -C "$P" config user.name test

# Synthesised per run rather than written as a literal. A credential-shaped
# string in a tracked file trips GitHub push protection, and allowlisting one
# in the repository that adds secret scanning would be the wrong precedent —
# this blocked the first push of this very branch. Random content also makes
# the redaction assert stronger: it checks the value the scan actually saw,
# not a fixed string an implementation could special-case.
SECRET="sk_live_$(python3 -c 'import secrets, string; print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(48)))')"
printf 'STRIPE_KEY = "%s"\n' "$SECRET" > "$P/src/config.py"
printf -- "-----BEGIN RSA PRIVATE KEY-----\nMIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu\nKUpRKfFLfRYC9AIKjbJTWit+CqvjWYzvQwECAwEAAQJAIJLixBy2qpFoS4DSmoEm\n-----END RSA PRIVATE KEY-----\n" > "$P/tests/fixtures/dummy.pem"
cat > "$P/src/client.js" <<'JS'
const apiKey = "9f3c2b1ae84d7f60c5a92e13b7d048fa6c1e5390";
const token = "Zm9vYmFyYmF6cXV4MTIzNDU2Nzg5MGFiY2RlZmdo";
JS
git -C "$P" add -A
git -C "$P" commit -qm seed

CLEAN="$TMP/clean"
mkdir -p "$CLEAN"
git -C "$CLEAN" init -q
git -C "$CLEAN" config user.email test@example.invalid
git -C "$CLEAN" config user.name test
echo "nothing to see" > "$CLEAN/README.md"
git -C "$CLEAN" add -A
git -C "$CLEAN" commit -qm seed

# --- the binary gate runs regardless of whether gitleaks is installed:
# --- an empty PATH entry makes `command -v gitleaks` fail deterministically.
STUB="$TMP/stub-path"
mkdir -p "$STUB"
OUT_NOBIN="$(PATH="$STUB:/usr/bin:/bin" "$SCAN" "$P" 2>&1 || true)"
PATH="$STUB:/usr/bin:/bin" "$SCAN" "$P" >/dev/null 2>&1 && NOBIN_RC=0 || NOBIN_RC=$?

assert "absent binary exits 0" '[ "$NOBIN_RC" -eq 0 ]'
assert "absent binary says so visibly" 'echo "$OUT_NOBIN" | grep -qi "gitleaks"'

# A scanner that cannot run must never look like a scanner that found
# nothing. Absent binary is a skip and exits 0 on purpose; a binary that
# errors is an unknown result, and reporting it as clean is the worst
# failure this tool has — it hands over false assurance about secrets.
ERRSTUB="$TMP/err-path"
mkdir -p "$ERRSTUB"
printf '#!/bin/sh\necho "gitleaks: fatal: could not read config" >&2\nexit 2\n' > "$ERRSTUB/gitleaks"
chmod +x "$ERRSTUB/gitleaks"
OUT_ERR="$(PATH="$ERRSTUB:$PATH" "$SCAN" "$CLEAN" 2>&1 || true)"
PATH="$ERRSTUB:$PATH" "$SCAN" "$CLEAN" >/dev/null 2>&1 && ERR_RC=0 || ERR_RC=$?

assert "failed scan does not exit 0" '[ "$ERR_RC" -ne 0 ]'
assert "failed scan is not reported as clean" '! echo "$OUT_ERR" | grep -qi "no findings"'
assert "failed scan surfaces the scanner error" 'echo "$OUT_ERR" | grep -qi "could not read config"'

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "  SKIP: gitleaks not installed — scan-behaviour asserts skipped"
  print_summary_and_exit
fi

OUT_CLEAN="$("$SCAN" "$CLEAN" 2>&1 || true)"
"$SCAN" "$CLEAN" >/dev/null 2>&1 && CLEAN_RC=0 || CLEAN_RC=$?
assert "clean repo exits 0" '[ "$CLEAN_RC" -eq 0 ]'

OUT="$("$SCAN" "$P" 2>&1 || true)"
"$SCAN" "$P" >/dev/null 2>&1 && RC=0 || RC=$?
assert "high-signal findings exit non-zero" '[ "$RC" -ne 0 ]'

# Redaction is the load-bearing property: the report travels into agent
# context, so the value must never appear even though the path does.
assert "no secret value in output" '! echo "$OUT" | grep -qF "$SECRET"'
assert "path is reported" 'echo "$OUT" | grep -q "src/config.py"'
assert "rule id is reported" 'echo "$OUT" | grep -q "stripe-access-token"'

# A specific rule is not automatically high signal — a private key inside a
# fixtures directory is a test asset, and promoting it trains the reader to
# scroll past the tier that matters.
HIGH="$(echo "$OUT" | sed -n '/high signal/I,/low signal/Ip')"
assert "high tier holds the real finding" 'echo "$HIGH" | grep -q "src/config.py"'
assert "fixture-path private key is demoted" '! echo "$HIGH" | grep -q "dummy.pem"'

assert "low-signal tail is collapsed to a count" 'echo "$OUT" | grep -qiE "[0-9]+ more|low signal.*[0-9]+"'
assert "generic findings are not listed individually" '[ "$(echo "$OUT" | grep -c "src/client.js")" -le 1 ]'

assert "no baseline file is written" '[ -z "$(find "$P" -name "*baseline*" -print -quit)" ]'

# --- catalog: the recipe that guards the wrong moment is gone, the one
# --- whose shape is right stays.
CAT="$AIKIT/standards/external/hooks-patterns.json"
assert "gitleaks-scan recipe removed" '! python3 -c "
import json,sys
d=json.load(open(\"$CAT\"))
sys.exit(0 if any(r[\"name\"]==\"gitleaks-scan\" for r in d[\"recommendations\"]) else 1)
"'
assert "block-env-edits recipe kept" 'python3 -c "
import json,sys
d=json.load(open(\"$CAT\"))
sys.exit(0 if any(r[\"name\"]==\"block-env-edits\" for r in d[\"recommendations\"]) else 1)
"'
assert "plugin standards mirror has no drift" 'bash "$AIKIT/bin/sync-plugin-standards.sh" --check >/dev/null 2>&1'

print_summary_and_exit
