## caveman (optional — token-compressed mode)

[caveman](https://github.com/JuliusBrussee/caveman) is available as a set of
opt-in skills. It compresses agent responses — drops articles, filler, and
hedging — for roughly 65% fewer output tokens, technical content intact.

- It is **opt-in**. Do not assume it. Activate with `/caveman` (or
  `/caveman lite|full|ultra`).
- Deactivate with `stop caveman` or `normal mode`.
- Commit messages, PR descriptions, and security notes stay in normal prose
  regardless of mode.
