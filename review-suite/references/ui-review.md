# UI / UX visual review

A first-class **dimension of review-suite, not a separate skill** — it shares all the orchestration
(levels, adversarial verify, remediation, feedback loop, ship-readiness). What differs is the
**method**, the **check catalog**, and the **tooling**.

**The defining difference: UI defects are found by LOOKING** — you cannot see "these two cards do the
same job," "the empty state is confusing," or "the buttons are misaligned" in source. So render the
actual UI, drive it through its states, screenshot each, and have a **vision-capable reviewer**
observe it against the catalog below.

## ⚠ DON'T LET THE UI LENS DEGRADE TO CODE-ONLY (escaped 2026-07-22)

In a **whole-repo or L3/L4 multi-agent audit**, the "UI" area silently becomes *just another
code-reading reviewer* unless you explicitly wire in a rendered pass — and then it misses exactly
the defects only rendering shows. This escaped a live L4 audit: a code-only "web-ui" reviewer
passed a manual page that renders **edge-to-edge with no margins** and a top nav that **overflows so
the Control gear falls off-screen on a phone** — both instantly obvious in a 390px screenshot,
invisible in the source (the CSS was print-styled `body{margin:0}`; the nav was a flex row with too
many items). **Rule:** if ANY audit area touches user-facing surfaces, that area's method MUST
include a rendered pass — headless-screenshot each key page at **mobile (~390px, and check 375px)
AND desktop**, vision-review the images, THEN code-verify. A UI area whose agent only read code has
NOT reviewed the UI. Cheap even without Playwright: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --screenshot=out.png --window-size=390,844 --virtual-time-budget=8000 URL`, then read the PNG.

## ⚠ PIXELS PROPOSE, CODE DISPOSES — the load-bearing discipline

**A screenshot tells you WHAT it looks like; only the code tells you WHY, and whether it's
intentional.** A pixels-ONLY review is mostly false positives — this was learned the hard way: a
vision pass flagged a greyed button as an "inconsistency" when the code showed it's `disabled`
because there's nothing to review; a gold button as "off-system" when it's a deliberate `brass`
emphasis class; and "permanent delete has no confirmation" when the code has a `confirm()` dialog a
static image can't show. **~5 of 6 findings evaporated on reading the code.**

So, non-negotiable: **every visual finding MUST be cross-referenced against the code that renders it
(and the interaction behavior) before it counts.** The vision pass *proposes*; the code + interaction
check *disposes*. This IS the adversarial-verify step for UI — do not skip it (running the review
inline without it is what produced the false positives).

### What a static screenshot CANNOT see — verify these in code or by DRIVING the app
- **Intentional disabled / empty states** — a greyed control may be `disabled` on purpose (nothing to
  act on). Check the code before calling it an inconsistency.
- **Emphasis by design** — a differently-coloured button may be a deliberate `brass`/hero/primary
  class, not a system crack. Check the class.
- **Hidden-when-N/A** — a "missing" element may be intentionally not rendered for this state.
- **`confirm()` / dialogs / toasts** — destructive-action confirmations and feedback don't appear in a
  static frame. Never claim "no confirmation" from a screenshot — read the handler or drive the click.
- **Hover / focus / active / loading / error / transition states** — invisible in a static shot;
  drive them (Playwright) or read the code.
- **JS-enabling / conditional rendering** — what's disabled/blank now may enable when data arrives.

**Rule:** if a finding depends on *behavior or intent* (disabled, confirmed, emphasized, conditional),
it is UNRELIABLE from a screenshot alone — confirm in code or by driving before reporting. Report only
what survives both the eye and the code.

## Method — render, drive, observe
1. **Drive the real app** in a headless browser (Playwright/Puppeteer): navigate each page/flow.
2. **Capture EVERY state**, not just the happy one: default · **empty** · **loading** · **error** ·
   populated · long-content/overflow · plus key **responsive breakpoints** (mobile/tablet/desktop).
3. **A vision-capable agent reviews the screenshots** against the catalog; each finding cites the
   component/template that renders it (file:line) + the screenshot as evidence.
4. **Cross-reference EACH finding against the code that renders it** (and drive the interaction where
   the claim is behavioral) — is it a real defect or an intentional state / by-design emphasis /
   a dialog the screenshot can't show? Only findings that survive both the eye AND the code are
   reported. This is mandatory, not optional (see "Pixels propose, code disposes" above).

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
