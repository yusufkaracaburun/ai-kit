# shellcheck shell=bash
# Score MCP + hook recommendations from standards/external/{mcp-servers,hooks-patterns}.json
# against a target project's detect-tooling.sh output and file presence.
#
# Reads:
#   - standards/external/mcp-servers.json   (signal → MCP server map)
#   - standards/external/hooks-patterns.json (signal → hook recipe map)
#   - detect-tooling.sh --json output for the target (frameworks, architecture, git remote)
#   - file existence in target root
#
# Writes (stdout): newline-separated "name<TAB>score<TAB>category<TAB>kind<TAB>reason" rows,
#   sorted high→low score. kind = "mcp" or "hook". Score 0 rows are filtered.

# Recommend MCP servers + hooks for a target project.
# Args: aikit_root, target_project_path
recommend_tools_external() {
  local aikit_root="$1" target="$2"
  local mcp_json="$aikit_root/standards/external/mcp-servers.json"
  local hooks_json="$aikit_root/standards/external/hooks-patterns.json"

  [ -f "$mcp_json" ] || { echo "Missing: $mcp_json" >&2; return 2; }
  [ -f "$hooks_json" ] || { echo "Missing: $hooks_json" >&2; return 2; }

  local detect_json
  detect_json="$("$aikit_root/bin/detect-tooling.sh" "$target" --json 2>/dev/null || echo '{}')"

  AIKIT_RECOMMEND_TARGET="$target" \
  AIKIT_RECOMMEND_MCP="$mcp_json" \
  AIKIT_RECOMMEND_HOOKS="$hooks_json" \
  python3 - "$detect_json" <<'PY'
import json, os, sys
from pathlib import Path

target = Path(os.environ["AIKIT_RECOMMEND_TARGET"])
mcp_path = Path(os.environ["AIKIT_RECOMMEND_MCP"])
hooks_path = Path(os.environ["AIKIT_RECOMMEND_HOOKS"])

try:
    detect = json.loads(sys.argv[1])
except Exception:
    detect = {}

frameworks = {s.lower() for s in detect.get("frameworks", []) if isinstance(s, str)}
arch = detect.get("architecture", {}) or {}
archs = set()
fe = (arch.get("frontend", {}) or {}).get("detected", "") or ""
be = (arch.get("backend", {}) or {}).get("detected", "") or ""
if fe: archs.add(fe.lower())
if be: archs.add(be.lower())

remote = ((detect.get("issue_tracker", {}) or {}).get("remote", "") or "").lower()


def file_exists(rel):
    p = target / rel
    return p.exists()


def score_entry(entry, kind):
    name = entry.get("name", "")
    category = entry.get("category", "")
    signals = entry.get("signals", {}) or {}
    universal = bool(entry.get("universal", False))
    score = 0
    reasons = []

    if universal:
        score += 1
        reasons.append("universal")

    for fw in signals.get("frameworks", []) or []:
        fwl = fw.lower()
        if fwl in frameworks or any(fwl in a for a in archs):
            score += 3
            reasons.append(f"framework:{fw}")
            break

    for a in signals.get("architectures", []) or []:
        if a.lower() in archs:
            score += 2
            reasons.append(f"arch:{a}")
            break

    matched_file = None
    for f in signals.get("files", []) or []:
        if file_exists(f):
            matched_file = f
            break
    if matched_file:
        score += 2
        reasons.append(f"file:{matched_file}")

    for host in signals.get("git_remote_host", []) or []:
        if host.lower() in remote:
            score += 3
            reasons.append(f"remote:{host}")
            break

    return name, score, category, kind, "; ".join(reasons) if reasons else "no signals"


def emit(path, kind):
    try:
        data = json.loads(path.read_text())
    except Exception as e:
        print(f"# skip {kind}: {e}", file=sys.stderr)
        return []
    rows = []
    for entry in data.get("recommendations", []) or []:
        name, score, category, k, reason = score_entry(entry, kind)
        if score > 0 and name:
            rows.append((name, score, category, k, reason))
    return rows


rows = emit(mcp_path, "mcp") + emit(hooks_path, "hook")
rows.sort(key=lambda r: (-r[1], r[3], r[0]))
for name, score, category, kind, reason in rows:
    print(f"{name}\t{score}\t{category}\t{kind}\t{reason}")
PY
}
