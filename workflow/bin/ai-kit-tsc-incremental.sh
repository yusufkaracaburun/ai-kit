#!/usr/bin/env bash
# Hygiene section: does a `tsc --noEmit` typecheck reuse its previous run?
#
# Reads package.json scripts and tsconfig files only; never runs tsc, so it
# needs no node_modules and no network. A config it cannot settle (an `extends`
# from an npm package, no tsconfig beside package.json, only references) gives
# no finding: a false alarm teaches the reader to ignore the section.
#
# Known misses: tsc behind another script, a Makefile or quotes
# (`concurrently "tsc --noEmit"`), a run in another directory through
# `pnpm --filter` and the like, files named on the command line, noEmit set only
# in the tsconfig, unbalanced quotes, and the --tsBuildInfoFile flag.
# Misread: `${configDir}` in outDir or rootDir, a subshell opened after `cd`
# (the directory resets to the package after `)`).
#
# Exit 0 = incremental, or there is nothing to grade. 1 = warning.
# Never above 1: a slow typecheck is not a broken install.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
TARGET="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "tsc-incremental: $PROJECT_PATH is not a directory — skipped."
  exit 0
}

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "tsc-incremental: not a git repository — skipped."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "tsc-incremental: python3 not found — skipped."
  exit 0
fi

# -I: the check runs from inside the project, whose own json.py must not load.
python3 -I - "$TARGET" <<'PY'
import json
import os
import re
import shlex
import subprocess
import sys

TARGET = sys.argv[1]
STRING = r'"(?:\\.|[^"\\])*"'


class Unknown(Exception):
    """A path and why its settings cannot be settled from the files in the repo."""


def rel(path):
    return os.path.relpath(path, TARGET)


skipped = []


def skip(path, why):
    skipped.append(path)
    print(f"tsc-incremental: {rel(path)} {why} — skipped.")


def git_files(*args):
    out = subprocess.run(["git", "-C", TARGET, "ls-files", "-z", *args, "--", "package.json", "*/package.json"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
    return {os.fsdecode(f) for f in out.split(b"\0") if f}


def manifests():
    files = git_files() - git_files("-c", "-i", "--exclude-standard")
    files = {f for f in files if not re.search(r"(^|/)(tests?|spec)/fixtures?/", f)}
    files.add("package.json")
    return [p for p in (os.path.join(TARGET, f) for f in sorted(files)) if os.path.isfile(p)]


def parse_jsonc(text):
    # Matching strings first keeps "@/*" and "http://" intact.
    text = re.sub(rf"({STRING})|//[^\n]*|/\*.*?\*/", lambda m: m.group(1) or "", text, flags=re.S)
    text = re.sub(rf"({STRING})|,(?=\s*[}}\]])", lambda m: m.group(1) or "", text)
    return json.loads(text)


def read_json(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            data = parse_jsonc(fh.read())
    except (OSError, ValueError, RecursionError):
        data = None
    if not isinstance(data, dict):
        raise Unknown(path, "is not readable JSON")
    return data


def tsc_runs(command, base):
    """Yield (cwd, lower-cased args, args) for every tsc or vue-tsc call."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    segments = [[]]
    for token in lexer:
        if token.strip(";&|()"):
            segments[-1].append(token)
        else:
            segments.append([")"] if ")" in token else [])
    cwd = base
    for tokens in segments:
        if tokens[:1] == [")"]:
            cwd, tokens = base, tokens[1:]
        if len(tokens) == 2 and tokens[0] == "cd":
            cwd = os.path.join(cwd, tokens[1])
            continue
        for i, token in enumerate(tokens):
            if token in ("echo", "printf") or re.match(r"(--filter|-F|-C|-r|--recursive|--cwd|--dir|--prefix|-w|--workspaces?)(=|$)", token):
                break
            if os.path.basename(token) in ("tsc", "vue-tsc"):
                args = tokens[i + 1:]
                yield cwd, [a.lower() for a in args], args
                break


def flag(low, *names):
    """A boolean tsc flag: True, False, or None when the call does not set it."""
    for i, arg in enumerate(low):
        if arg in names:
            return low[i + 1:i + 2] != ["false"]
    return None


def value(low, args, *names):
    for i, arg in enumerate(low[:-1]):
        if arg in names:
            return args[i + 1]
    return None


def graded(low):
    return (flag(low, "--noemit")
            and not any(a in ("-b", "--build") for a in low)
            and "--tsbuildinfofile" not in low
            and not any(a.endswith((".ts", ".tsx", ".mts", ".cts")) for a in low))


def compiler_options(path, chain=()):
    """Merged compilerOptions over the extends chain, child last."""
    if not os.path.isfile(path):
        raise Unknown(path, "not found")
    config = read_json(path)
    bases = config.get("extends") or []
    merged = {}
    for base in bases if isinstance(bases, list) else [bases]:
        if not isinstance(base, str) or not base.startswith(("./", "../", "/")):
            raise Unknown(path, f"extends {base}, which this check does not resolve")
        base_path = os.path.normpath(os.path.join(os.path.dirname(path), base))
        if not os.path.isfile(base_path):
            base_path += ".json"
        if base_path in chain or not os.path.isfile(base_path):
            raise Unknown(path, f"extends {base}, which is circular or missing")
        merged.update(compiler_options(base_path, (*chain, path)))
    options = config.get("compilerOptions")
    for name, setting in options.items() if isinstance(options, dict) else ():
        if name in ("tsBuildInfoFile", "outDir", "rootDir") and isinstance(setting, str):
            setting = os.path.join(os.path.dirname(path), setting)
        merged[name] = setting
    return merged


def findings(config, low):
    options = compiler_options(config)
    top = read_json(config)
    if top.get("files") == [] and top.get("references") and not top.get("include"):
        raise Unknown(config, "has no files of its own, only references")
    for name in ("incremental", "composite"):
        override = flag(low, f"--{name}")
        if override is not None:
            options[name] = override
    if not (options.get("incremental") or options.get("composite")):
        return ["incremental is off"]
    config_dir = os.path.dirname(config)
    paths = {name: options[name] for name in ("tsBuildInfoFile", "outDir", "rootDir") if isinstance(options.get(name), str)}
    explicit = paths.get("tsBuildInfoFile")
    if explicit:
        # Relative to the config, so a checkout that itself sits under node_modules does not match.
        if "node_modules" in os.path.relpath(explicit, config_dir).split(os.sep):
            return ["tsBuildInfoFile points into node_modules; worktrees that symlink node_modules share that "
                    "file, and a buildinfo from another path costs more than a cold run"]
        return []
    stem = os.path.splitext(os.path.basename(config))[0]
    out_dir = paths.get("outDir", config_dir)
    if "outDir" in paths and "rootDir" in paths:
        out_dir = os.path.join(out_dir, os.path.relpath(config_dir, paths["rootDir"]))
    buildinfo = rel(os.path.normpath(os.path.join(out_dir, f"{stem}.tsbuildinfo")))
    ignored = subprocess.run(["git", "-C", TARGET, "check-ignore", "-q", "--", buildinfo], stderr=subprocess.DEVNULL)
    return [f"{buildinfo} is not ignored by git"] if ignored.returncode == 1 else []


found = []
checked = 0
for manifest in manifests():
    try:
        scripts = read_json(manifest).get("scripts")
    except Unknown as why:
        skip(*why.args)
        continue
    for name, command in scripts.items() if isinstance(scripts, dict) else ():
        try:
            runs = list(tsc_runs(command, os.path.dirname(manifest))) if isinstance(command, str) else []
        except ValueError:
            runs = []
        for cwd, low, args in runs:
            if not graded(low):
                continue
            config = os.path.normpath(os.path.join(cwd, value(low, args, "-p", "--project") or "."))
            if os.path.isdir(config):
                config = os.path.join(config, "tsconfig.json")
            try:
                for finding in findings(config, low):
                    line = f"{rel(config)}: {finding}"
                    if line not in found:
                        found.append(line)
                        print(f"WARN: {line} (script \"{name}\" in {rel(manifest)})")
            except Unknown as why:
                skip(*why.args)
                continue
            checked += 1

if found:
    print()
    print("Fix: add \"incremental\": true to the tsconfig, keep *.tsbuildinfo in .gitignore, and")
    print("leave the file beside the tsconfig (no tsBuildInfoFile). A fresh worktree pays one full run.")
    sys.exit(1)
if checked:
    print("tsc-incremental: ok — every graded tsc --noEmit script builds incrementally.")
elif not skipped:
    print("tsc-incremental: no tsc --noEmit script to grade — skipped.")
PY
