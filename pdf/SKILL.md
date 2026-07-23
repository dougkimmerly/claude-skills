---
name: pdf
description: Render HTML into a polished, print-ready PDF — page-number footers, a back-of-book index with REAL page numbers, framed screenshots, print CSS. Use when asked to make/generate/produce/build a PDF, add page numbers, add an index, or turn an HTML manual/report/document/flyer into a PDF. Drives installed Google Chrome over the DevTools Protocol (the plain `chrome --print-to-pdf` CLI can't do footers). NOT for reading/extracting text from an existing PDF.
---

# PDF — HTML → polished PDF

Turn an HTML document into a print-ready PDF with **page numbers** and, optionally, a **back-of-book index with accurate page references**. The engine is the Google Chrome already on the machine, driven over the DevTools Protocol — no `npm install`, no LaTeX, no wkhtmltopdf.

## Why this skill exists

`"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --print-to-pdf=out.pdf file://…` works, **but it cannot add a page-number footer** (the footer template lives in the DevTools `Page.printToPDF` params, not on the CLI). Everything here routes through `render.mjs`, which sets that footer. If a doc already has page numbers or an index and you regenerate with the bare CLI, you'll silently drop them.

## Prerequisites (check first)

- **Google Chrome** installed (`ls "/Applications/Google Chrome.app"`, or set `CHROME=/path/to/chrome`).
- **Node ≥ 22** (`node --version`) — `render.mjs` uses Node's built-in `fetch` + `WebSocket`, no packages.
- For the index only: **pypdf** (`python3 -c "import pypdf"`, else `pip install pypdf`).

## Recipe 1 — HTML → PDF with page numbers (the common case)

```bash
node ~/.claude/skills/pdf/render.mjs /abs/path/doc.html /abs/path/doc.pdf
```

Options: `--no-footer` · `--footer '<html>'` (custom; Chrome fills `<span class="pageNumber">`/`<span class="totalPages">`) · `--a4` · `--margin 0.7` (inches) · `--wait 2500` (ms to settle images/fonts) · `--no-background` · `--chrome /path`. It also accepts an `http(s)://` URL instead of a file.

## Recipe 2 — add a back-of-book index (real page numbers)

Write an `entries.json` — a list of `[label, phrase]`, where `phrase` is a short, distinctive string that appears in that topic's section:

```json
[["Backup vault", "backup vault"],
 ["Ingesting footage", "ingesting new footage"],
 ["360 footage", "reframe to use"]]
```

```bash
python3 ~/.claude/skills/pdf/add_index.py /abs/doc.html entries.json --out /abs/doc.pdf
```

It **two-passes**: renders once to learn which page each phrase lands on, injects an alphabetised, two-column index (its own CSS — the target HTML needs nothing) at the very back so earlier page numbers don't shift, then renders the final PDF. Idempotent (index lives between `<!-- PDFX-INDEX:START/END -->` markers). A phrase that no longer matches is **reported, not dropped** — fix the phrase and re-run. Insert point defaults to before `<footer>`/`</body>`; override with `--insert-before '<marker>'`.

Page numbers stay accurate on re-runs because the index is appended last. If you add a *body* section that pushes content onto new pages, just re-run — it re-measures.

## Writing HTML that prints well

- **`@page { size: letter; margin: 18mm 17mm; }`** and **`html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }`** so background colours/tints survive.
- **`section, figure { break-inside: avoid; }`** keeps a block off a page seam; **`.pagebreak { break-before: page; }`** forces one.
- **Cap tall images** so one screenshot doesn't eat a page: `img { max-width:100%; max-height:118mm; width:auto; height:auto; }`.
- **Annotated screenshots** (numbered callout pins over an image): wrap the `<img>` in a `position:relative` box and place pins with **percentage** `left`/`top` so they track the image at any print scale; control overall size with a `max-width` on the *figure*, not the image. (Worked example: shard-editing `docs/library-manual.html`, the `.annot`/`.pin` blocks.)
- Use a `@media screen { … }` block for on-screen width (`max-width`); the `@page` rules govern print regardless.
- Grab screenshots for a manual from a live app with the Playwright MCP, then crop with `ffmpeg -i in.png -vf "crop=W:H:X:Y" out.png`.

## Gotchas

- **Fancy glyphs fall back badly** in serif print fonts (↻ ⚓ ⊕ …). Spell them out, or accept the fallback — check the rendered PDF.
- **`file://` vs the Playwright MCP:** the MCP blocks `file:`, but `render.mjs` drives your own Chrome and handles `file://` fine. If a doc pulls assets by absolute path (`/nav.js`), those 404 under `file://` — harmless for print, or serve it: `python3 -m http.server` in the doc's dir and pass the `http://localhost:…` URL.
- **Verify the result** — read the PDF back (the Read tool renders PDF pages) and eyeball footers, the index page numbers against real content, and image placement.
- **Chrome not at the default path?** `CHROME=/path/to/chrome node render.mjs …`.

## Project-local copies are fine (and sometimes required)

A repo that must stay **portable / self-contained** (e.g. shard-editing, handed off to non-devs) keeps its *own* copy of the renderer + an index-builder tuned to its doc — it can't depend on a skill under `~/.claude/skills/`. That's not forbidden duplication; it's a portable deliverable. This skill is the general-purpose home; shard-editing's `tools/render_docs_pdf.mjs` + `tools/build_manual_pdf.py` are the project-local, entries-baked variant. Improve both if you change the technique.

## Version control

Real-file universal skill → back it up in `claude-skills`: `cd ~/.claude/skills && git add pdf && git commit && git push` (see the `skills` skill / ADR 0022).
