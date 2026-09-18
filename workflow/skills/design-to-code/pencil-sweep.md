# Pencil sweep scripts

Reference for the *audit* flow's structural sweep on a `.pen` design. Every
script runs through the Pencil MCP `execute` tool against the active file —
never `Read`/`Grep` on a `.pen`. Fill two parameters from the project's
overlay before running; the project's master naming prefix (`acme-*`) is what
a promoted structure gets named, not a script input:

| Parameter | Meaning | Example |
|-----------|---------|---------|
| `SCOPE` | node id of the section or screen under review | `"h36gf"` |
| `RAW_RE` | name pattern of hand-built structures that should not repeat | `/^(sec-\|row-\|card-)/` |

## When each step runs

| Step | Run when | What it catches |
|------|----------|-----------------|
| Structural sweep (below) | always — it is cheap | collapsed frames, real clipping, loose copies, repeated raw structures |
| Full-scale render | right after `.pen` edits only | what a thumbnail hides at true pixel size |
| Live at two densities / viewports | always, for every screen that is in code | everything else — copy, sizing, keyboard, data, per-device drift |

Evidence from a 39-screen re-gate: sweep 0 findings, render 0, live 22 drifts
plus 2 bycatch bugs. Never skip live.

## 1. Structural sweep

```js
Get(SCOPE,(n,c)=>{
  if(n.type==="frame"&&n.children&&n.children.length>=2&&n.layout===undefined){
    Print("HORIZONTAL-CHECK:",n.id,n.name,"children="+n.children.length,"parent="+(c.parentCtx?c.parentCtx.node.name:"?"))
  }
  if(c.problems&&c.problems!=="partially clipped"&&c.problems!=="fully clipped"){
    Print("REAL-PROBLEM:",n.id,n.name,c.problems)
  }
})
Print("sweep-done")
```

- `REAL-PROBLEM` — almost always genuine; investigate every line.
- `HORIZONTAL-CHECK` — a frame with two or more children and no explicit
  `layout` defaults to a horizontal row. Most are intentional; the one to
  watch is a frame that *just* gained a second child (a divider, a bar, an
  action row) — that is the shape of a divider collapsed to 1×1px. No
  structural filter separates the two (a 30-page site measured 1013 such
  frames, all intentional rows), so run it on one screen at a time and read
  only the frames touched since the last gate — never on the whole file.
- Promoted master left on `width:"fill_container"` instead of a fixed content
  width stretches to whatever wide section it lives in. For every master
  touched since the last gate: `Get(masterId,{depth:0})` and read `width`.
- Judging tokens: read with `resolveVariables:false`. A resolved read turns
  every `$token` into hex and hides whether a fill or radius is tokenized or
  raw — a raw-hex component looks fine.
- Trailing dead space: the last child's bottom must equal the frame's inner
  height. If not, the slot is a fixed height that outgrew its content — set it
  to `fit_content` or size the frame from the measured pieces, then re-check.

## 2. Promote sweep

Nothing that has a master may exist as a loose copy; no raw structure may
repeat across two or more screens; states of one screen are instances of one
master with `enabled`/text overrides, never per-state copies.

```js
const masters = new Set(); Get(n=>{ if(n.reusable) masters.add(n.name) });
const seen = {};
Get(SCOPE,(n,c)=>{
  if(n.type==="frame" && !n.reusable && n.name && masters.has(n.name)) Print("LOOSE-COPY:",n.id,n.name,"in",c.parentCtx?.node.name);
  if(n.type==="frame" && n.name && RAW_RE.test(n.name) && c.parentCtx) (seen[n.name] ??= new Set()).add(c.parentCtx.node.id);
  if(n.type==="broken_ref") Print("BROKEN-REF:",n.id,"in",c.parentCtx?.node.name);
});
for (const [name,parents] of Object.entries(seen)) if(parents.size>=2) Print("RAW-REPEAT:",name,"x"+parents.size);
Print("promote-sweep-done")
```

- `LOOSE-COPY` — replace with an instance: `Insert` a `ref` plus overrides,
  `Move` into place, `Delete` the copy. Do not `Update` children of an
  instance to "fix" it — that wipes the descendants.
- `RAW-REPEAT` — promote to a master under the project's naming prefix first, then instance it.
- `BROKEN-REF` — an instance whose master no longer exists. Silent and toxic:
  it collapses to 1px (`fit_content`) or an empty box (`fill_container`), and
  the export draws a red hatch that a raster tolerance of a few percent hides
  completely — one sat in a dashboard baseline for three months. It cannot be
  `Update`d (`Unknown node type: broken_ref`): `Replace(id,{type:"ref",ref:"…"})`
  and restore the descendant overrides. Run this after **every** library refactor.
- Library sections (components, shell) are in scope too, not only screens.

## 3. Exports for the prove step

```js
Export([frameId],"png","<scratchpad>/frames",{scale:1.5})   // writes <dir>.png/<id>.png — one folder per call
Export([SCOPE],"html-css","<scratchpad>/verify.html")      // full-scale render; serve it, file:// is blocked in the browser extension
```

- There is no SVG export target. Assets the code needs as vectors go out as
  PNG at 1×/2×/3×.
- Generated vector content (a `Generate`-SVG mark) can render blank in the
  `html-css` export while it is correct in Pencil. An unexpectedly empty spot
  → confirm with `TakeScreenshot` on that node before calling it a bug.
- **Exports go stale silently.** Fresh or `Move`d nodes render the old tree in
  the same and the next call: export, export again, then measure. A frame whose
  container sits at a fractional canvas position exports one row too tall —
  round the container's `x`/`y` to integers and re-export every frame. An
  export pinned to the module file's hash still ages when an *imported* library
  changes: re-export after any library change, or pin the library hash too.
  `placeholder:true` renders blank; only a full tab close + reopen is
  guaranteed to read the file from disk.
- **Is the file on disk what the app shows?** Compare before building or
  hashing — never assume which side is behind. `git status --short *.pen`,
  then read one recently edited value through the MCP and against the file.
  The app has been seen not flushing MCP edits for a session (2026-09-05) and
  writing within seconds, new node ids included (2026-09-19). Converge by
  writing the same value to the lagging side. Building against a stale file
  costs half a session.

## Plain-JSON `.pen`

Some projects keep an unencrypted, JSON `.pen` in the repo. Then the sweep is
a script, not an MCP session — the same two checks in ~15 lines:

```js
import { readFileSync } from 'node:fs';
const doc = JSON.parse(readFileSync('design.pen', 'utf8'));
const SCOPE = process.argv[2], RAW_RE = /^(sec-|row-|card-)/, masters = new Set(), seen = {};
function* walk(n, p = null) { yield [n, p]; for (const c of n.children ?? []) yield* walk(c, n); }
for (const [n] of walk(doc)) if (n.reusable) masters.add(n.name);
const root = SCOPE ? [...walk(doc)].find(([n]) => n.id === SCOPE)?.[0] : doc;
for (const [n, p] of walk(root)) {
  if (n.type === 'frame' && (n.children?.length ?? 0) >= 2 && n.layout === undefined) console.log('HORIZONTAL-CHECK', n.id, n.name);
  if (n.type === 'frame' && !n.reusable && masters.has(n.name)) console.log('LOOSE-COPY', n.id, n.name, 'in', p?.name);
  if (n.type === 'frame' && p && RAW_RE.test(n.name ?? '')) (seen[n.name] ??= new Set()).add(p.id);
}
for (const [name, ps] of Object.entries(seen)) if (ps.size >= 2) console.log('RAW-REPEAT', name, 'x' + ps.size);
```

`node sweep.mjs <screenId>` — the scope argument matters: unscoped, the
`HORIZONTAL-CHECK` list is the whole file. Run it as an audit, never as a
commit gate — a frame left without a layout in the design tool must not fail
a code commit. Validated on a real 30-page site: 18 `LOOSE-COPY` hits were
18 genuine hand-built copies of a master that already had 64 instances.
