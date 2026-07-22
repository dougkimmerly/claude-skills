# UI / UX visual review

A first-class **dimension of review-suite, not a separate skill** — it shares all the orchestration
(levels, adversarial verify, remediation, feedback loop, ship-readiness). What differs is the
**method**, the **check catalog**, and the **tooling**.

**The defining difference: UI defects are found by LOOKING, not by reading code.** You cannot see
"these two cards do the same job," "the empty state is confusing," "the buttons are misaligned," or
"the contrast fails" in source. So UI review's **real-path verification IS the primary method**:
render the actual UI, drive it through its states, screenshot each, and have a **vision-capable
reviewer** observe it against the catalog below.

## Method — render, drive, observe
1. **Drive the real app** in a headless browser (Playwright/Puppeteer): navigate each page/flow.
2. **Capture EVERY state**, not just the happy one: default · **empty** · **loading** · **error** ·
   populated · long-content/overflow · plus key **responsive breakpoints** (mobile/tablet/desktop).
3. **A vision-capable agent reviews the screenshots** against the catalog; each finding cites the
   component/template that renders it (file:line) + the screenshot as evidence.
4. **Adversarially verify** like any finding (really wrong, or intended?). Real-path is automatic
   here — you're already looking at the true render.

## Automated first pass — the UI equivalent of SAST (run at L0)
- **axe-core** / **pa11y** — accessibility violations (contrast, labels, roles, landmarks). Cheap, deterministic.
- **Lighthouse** — accessibility + performance + best-practices scores.
- **Visual-regression** — Playwright snapshots / Percy / Chromatic: catch unintended visual diffs
  against a baseline on every change — the UI equivalent of a test suite.

## The UI check catalog (lenses for the vision reviewer)
- **Visual hierarchy** — does the eye hit the primary action first? importance encoded by
  size/weight/color/position?
- **Layout & alignment** — consistent grid, aligned edges, no few-pixel drift.
- **Spacing & rhythm** — a spacing scale, not arbitrary values; consistent padding/margins; breathing room.
- **States** — every empty / loading / error / partial state *designed* (not blank, not a raw
  traceback); clear recovery from errors.
- **Affordance & discoverability** — controls look interactive; the next step is obvious; no hidden
  critical actions.
- **Consistency / design system** — the same component looks + behaves the same everywhere; one
  button style, one card style; matches established tokens.
- **Redundancy & dead-ends** — two controls doing one job (review-types #13 — the watch-rotation
  case), a legacy widget beside its replacement, a nav item that goes nowhere, a modal with no close.
- **Microcopy** — labels/buttons/errors clear, human, consistent in voice; errors name the fix.
- **Information density** — not cramped, not sparse; scannable; progressive disclosure for complexity.
- **Responsive / cross-device** — works at each breakpoint; no horizontal scroll, no clipped content;
  touch targets ≥ ~44px.
- **Accessibility (WCAG)** — contrast ≥ 4.5:1 text; keyboard-navigable; visible focus; labels/alt
  text; ARIA where needed; respects reduced-motion; no keyboard traps.
- **Motion & feedback** — actions give feedback (hover/active/loading); transitions purposeful.
- **Trust & polish** — no broken images, lorem, overlapping/clipped text, or console errors.

## How it wires into review-suite
- **Scope:** "UI review" / "review this screen/page/flow" → this dimension.
- **Level:** L1 = a11y + visual-regression + Lighthouse on the changed screen. L2 = + a vision review
  of the changed states. L3 = + drive every state/breakpoint, adversarially verified. L4 = whole-app
  UI sweep + **design-system consistency across every screen** (part of ship-readiness).
- **Multi-agent workflow:** UI-area agents **drive + screenshot + vision-review** (a vision-capable
  model) instead of reading code — everything else (verify, synthesize, remediation) is unchanged.
  Give each agent a page/flow; it captures states, reviews against the catalog, returns findings +
  screenshots.
- **Remediation:** same fix loop, but a UI regression's "regression test" is a **visual-regression
  snapshot** (the UI equivalent of the code regression test).
- **Ship-readiness:** add — every state designed (empty/loading/error), a11y scan clean,
  visual-regression baseline green, key flows driven on real breakpoints, design-system consistent.

## Tooling note (this environment)
- Drive with **Playwright** — AppleScript can't see Chrome here; use Playwright/pgrep, not osascript.
- A **vision-capable Claude** reviews the screenshots. The `frontend-design` skill (design quality)
  and the `run` skill (launch the app) are natural companions.
