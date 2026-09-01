---
name: design-direction
description: Research, compare, select, review, and safely evolve a website's visual direction before implementation. Use when choosing styles, colors, typography, imagery, motion, or when an existing design feels generic, off-brand, dated, or conversion-weak.
---

# Design direction

Choose the visual system before polishing screens. Ground the choice in the
audience, offer, task, brand, competitors, accessibility, and current evidence;
never in color folklore or whichever gallery is fashionable today.

Already have a direction and just want to see it running in code? Use
[prototype](../prototype/SKILL.md) instead — this skill decides the
direction and produces a document, prototype renders throwaway variants of
one direction you already picked.

## Process

### 1. Pick the mode

- **New** — establish a direction before designing a new site or product.
- **Review** — diagnose an existing design and recommend what to preserve,
  change, and remove. Read [REVIEW.md](REVIEW.md).
- **Refresh** — create comparable alternatives for an existing design. Keep the
  original intact and do not apply a direction until the user selects it.

State the mode and the decision to be made. Ask only for missing information
that would materially change the result. Work with explicit assumptions when
the gaps are low-risk.

### 2. Build the evidence brief

Capture:

- audience, situation, device context, pains, anxieties, and desired feeling;
- offer, primary action, business model, trust burden, and conversion journey;
- existing brand assets, constraints, content, design system, and technology;
- direct competitors, category conventions, and useful adjacent categories;
- required accessibility level, languages, markets, and cultural context;
- success metric and the decision deadline.

Browse for current competitors, category patterns, and inspiration. Prefer live
pages over remembered examples. Record the URL, access date, observation, and
why it matters. Follow the source hierarchy and research method in
[RESEARCH.md](RESEARCH.md).

If the host supports subagents and at least two research lanes are independent,
optionally delegate read-only competitor analysis and standards/inspiration
collection in parallel. Keep audience and brand synthesis in the main agent.
Give each lane distinct scope and require sources. Without subagents, run the
same lanes inline; never weaken the method because the host lacks delegation.

### 3. Translate evidence into principles

Write 3–5 project-specific design principles. Each principle must connect:

`evidence → design implication → behavior to avoid`

Example: “First-time buyers fear choosing the wrong variant → lead with a
plain-language selector and immediate reassurance → avoid a decorative hero
that delays product selection.”

Do not claim that a hue universally means trust, urgency, youth, or luxury.
Color effects depend on context, saturation, contrast, culture, and category.

### 4. Create comparable directions

Produce three genuinely distinct directions, not three palette swaps. Compare
the same representative page, content, hierarchy, and user journey in every
direction, on desktop and mobile. Hold copy and feature scope constant.

For each direction define:

- a memorable name and one-sentence concept;
- semantic palette roles with hex values: canvas, surface, text, muted text,
  primary action, secondary action, accent, success, warning, error, borders;
- display and body typography, weights, scale, line height, and fallback stack;
- composition, grid, content width, density, spacing, radius, border, and shadow;
- imagery or illustration art direction (e.g. photographic, 3D, line-art,
  abstract-gradient) and what imagery to reject;
- background pattern, texture, or gradient treatment, and where it earns its
  place versus a plain surface;
- component character and one ownable visual motif;
- motion principles: micro-interactions, hover/scroll-triggered reveals,
  page-transition feel, durations, easing, and reduced-motion behavior;
- why it fits the audience and offer, plus strengths, risks, and implementation
  cost.

Use a bounded content container where readability and composition benefit, but
do not impose a fixed-width body. Let backgrounds and intentional elements span
the viewport. Verify responsive behavior at narrow and extra-wide widths.

Check normal text and large text contrast against WCAG 2.2 AA. Check focus,
hover, error, disabled, and selected states; never communicate state by color
alone. Motion must clarify hierarchy or feedback, not merely make the page busy.

### 5. Score and recommend

Score every direction from 1–5, with one sentence of evidence per score:

| Criterion | Weight |
| --- | ---: |
| Audience and context fit | 20% |
| Brand and offer fit | 15% |
| Clarity and conversion alignment | 20% |
| Trust and credibility | 10% |
| Distinctiveness in the live category | 10% |
| Accessibility and responsive resilience | 15% |
| Implementation and maintenance cost | 10% |

Recommend one direction, name the trade-off, state confidence, and identify the
assumption most worth validating. A weighted score supports judgment; it does
not replace it.

### 6. Validate before rollout

Test the same task and viewport across directions. At minimum run:

1. a five-second first-impression check: what is this, who is it for, and what
   should I do next?;
2. one short mobile task with target users;
3. an accessibility and contrast pass;
4. a conversion-risk review covering CTA clarity, trust, distractions, and
   friction.

Use behavioral evidence when available. Do not present A/B testing as a cure for
an underpowered traffic level; prefer interviews, preference-with-reason tests,
and task observation until sample size is credible.

### 7. Document the decision

Create or update `DESIGN_DIRECTION.md` with:

1. context, audience, primary journey, and success metric;
2. dated evidence and source links;
3. principles and rejected clichés;
4. compared directions and scorecard;
5. selected direction, rationale, confidence, and open assumptions;
6. design tokens and usage rules;
7. responsive, accessibility, imagery, and motion rules;
8. validation plan and decision log.

Keep observations separate from interpretations and decisions.

### 8. Apply only with authorization

Research, audit, and recommendations are read-only. When the user explicitly
asks to implement or selects a direction, apply the smallest coherent update.
Preserve the original or a recoverable baseline, update shared tokens before
individual screens, and verify representative desktop/mobile pages. Do not
silently restyle unrelated product areas.

## Quality gate

Before finishing, verify:

- research preceded styling and current claims have dated source links;
- the audience can recognize themselves above the fold;
- all directions use the same comparison frame and differ beyond color;
- the recommendation follows evidence, not a gallery trend;
- palette roles, typography, imagery, pattern/texture, motion, layout, and
  states are specified;
- WCAG 2.2 AA contrast and reduced motion are covered;
- the result has an ownable motif and avoids template-like AI sameness;
- the original remains recoverable and no unselected direction was applied.

