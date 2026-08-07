---
name: ui-design
description: Doug's cross-repo UI design philosophy — compact, data-dense interfaces where position and colour carry meaning, everything fits above the fold, icons beat words (but every control has a tooltip), and you tap the meaningful thing to act on it. Use BEFORE building or reviewing any UI/frontend/screen/page/component in ANY repo (Maggie player, cruising-app, command-centre, dashboards, admin consoles). Owns the PRINCIPLES; each repo's own style guide owns its TOKENS (colours, class names, skeleton) and should reference this. Not a chart/dataviz spec (see `dataviz`) and not about generating novel aesthetics (see `frontend-design`).
---

# UI Design — how Doug builds interfaces

The house style is **compact, data-rich, and meaningful**: a control's position tells
you what it's for, its colour tells you its state, and the whole thing fits on one
screen. This is the way Doug likes to build UI — codified once so every frontend job in
every repo starts here instead of re-deriving it.

This skill owns the **principles**. Each repo keeps its own style guide for **tokens** —
colours, CSS variables, class names, page skeleton (e.g.
`music-library/.claude/docs/styling.md`, `boat/cruising-app/docs/STYLE-GUIDE.md`). Those
inherit these principles and add repo specifics. If a repo has no style guide yet, these
principles still apply.

Reference model in Doug's world: the **Control4 Navigator** — dense, glanceable,
every room/session controllable in place. Aim there, not at a sparse marketing page.

## The seven principles

### 1. Everything above the fold — going below must be EARNED
The default is: it all fits on one screen, no scroll. Scrolling is a cost you pay only
for a genuinely good reason (a long list the user came specifically to browse — a queue,
a history, lyrics). Chrome, controls, status, and the primary content should be visible
at once. **If a screen needs to scroll to reach a control, the layout is wrong — consolidate
first.** This is the enforcing constraint behind everything below: density, consolidation,
and icon-over-word all exist to keep you above the fold.
- *Apply:* budget the viewport. Before adding a row, ask "what does this push off-screen?"
  If the answer is a control, merge or iconify instead of stacking.

### 2. Data density — every element earns its place
Compact and information-rich. Ruthlessly consolidate redundancy: two elements that say the
same thing become one. Whitespace is fine when it groups; whitespace that's just padding an
under-full screen is waste.
- *Apply:* delete-test every label. If removing it loses no meaning, remove it. Collapse
  "Office / Playing in Office" → one "Office". Fold a standalone "Turn off" + "Control
  rooms" + "History" into the objects they act on (see #6).

### 3. Position carries meaning
Group by meaning and order by priority. Things that are the same *kind* of data live
together; the most important control sits where the eye lands first.
- *Apply:* separate "what's playing" (title/artist/art) from "where/how it's playing"
  (room/volume/playlist) — they're different data, so different zones. Put the control you
  reach for most (volume, in a room) at the top of its box, not buried at the bottom.

### 4. Colour carries state, not decoration
Colour means something: playing vs idle, active vs inactive, the current line, a warning.
A colour with no state behind it is noise. Reserve the accent for "this is live / this is
now / act here."
- *Apply:* a filled dot = playing; the highlighted lyric line = the current line; the
  primary/accent colour marks the one live thing, not every button. If everything is
  coloured, nothing reads as active.

### 5. Icons over words — but never mystery-meat
Prefer an icon to a sentence; prefer a glyph to a button-with-a-label. BUT every icon and
every control carries a **hover/long-press tooltip (`title`)** that says exactly what it
does. Density without discoverability is a puzzle, not a UI.
- *Apply:* 🕐 for history, a speaker glyph for a room/volume, a trash glyph for remove —
  each with a `title`. Fewer words on screen, full clarity on hover.

### 6. Direct manipulation & progressive disclosure — tap the thing
You act on an object by tapping the object, not a separate control that refers to it. Hide
secondary depth behind the primary thing and reveal on demand. One control = one meaning
(no two controls that do overlapping jobs).
- *Apply:* tap the room *name* to open its multiroom controls (don't add a "Control rooms"
  button next to it); tap the art to flip to lyrics and back (don't add an Art/Lyrics
  toggle); put history behind an icon that reveals it in place. Each of these removes a
  control *and* a word.

### 7. Touch-first
This runs on phones and tablets. Real tap targets (~44px), no hover-only actions (the
tooltip is a bonus on hover, never the only way to reach a function), gestures where they're
natural (tap-to-flip, swipe a sheet).

## Review checklist (run against any screen)
- [ ] Does it fit above the fold? If it scrolls, is that scroll *earned* (a list the user
      came to browse), or a layout that should be consolidated?
- [ ] Any two elements saying the same thing? Merge them.
- [ ] Is related data grouped, and is the most-used control where the eye lands first?
- [ ] Does every colour encode a state? Any decorative accent stealing "active" meaning?
- [ ] Words that could be an icon? Icons without a `title` tooltip?
- [ ] Any control that refers to an object instead of *being* the tappable object?
- [ ] 44px targets, no hover-only functions?

## Relationship to other artifacts
- **Per-repo style guides own tokens** (colours, variables, class names, skeleton) and
  should link here for the *why*. Update the token guide in the same commit as a token
  change; update THIS skill when the philosophy itself evolves.
- **`dataviz`** owns charts/graphs colour systems — use it for any chart, not this.
- **`frontend-design`** is for generating distinctive novel aesthetics from scratch; this
  skill is the standing house style to conform to.
- When you learn a new principle from Doug (like "above the fold must be earned"), add it
  here — that's how the house style compounds.
