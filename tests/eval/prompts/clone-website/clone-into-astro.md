---
id: clone-into-astro
skill: clone-website
expects:
  - detects Astro from astro.config.* and uses src/pages/, src/components/sites/<site>/ and public/sites/<site>/
  - lists the host site's own rules (CLAUDE.md, design rules) in step 1 and flags source patterns that collide
  - observes desktop and mobile with real wheel/touch input before building, with screenshots named by section or scroll percentage
  - downloads the real assets and verifies their type with `file`, not trusting the URL extension
  - builds interactions as vanilla <script> plus CSS; adds a React island only for a JS animation library need
  - leaves `name` off form fields nothing reads, or gives the form a real action
  - runs the project's `check` script (or installs `@astrojs/check typescript` before `npx astro check`), then `npm run build` and a side-by-side comparison before reporting, and lists remaining gaps
---

# Prompt

Kloon deze site: https://example.framer.website. Zet hem in dit Astro-project
onder /demo, zelfde layout en animaties.
