#!/usr/bin/env python3
"""Add a back-of-book Index (with REAL page numbers) to an HTML document, then
render it to PDF. Self-contained: injects its own CSS, so the target HTML needs
no special classes.

    python3 add_index.py <doc.html> <entries.json> [--out doc.pdf]
                         [--insert-before '<footer>'] [--title Index]

entries.json is a list of [label, phrase] pairs, where `phrase` is a short,
distinctive, lower-case-able string that appears in that topic's section:

    [["Backup vault", "backup vault"],
     ["Ingesting footage", "ingesting new footage"],
     ["360 footage", "reframe to use"]]

Page numbers are correct because it's a TWO-PASS build: render once to learn
which page each phrase lands on, inject the index at the very back (so earlier
page numbers don't shift), then render the final PDF. A phrase that no longer
matches is reported, not silently dropped. Re-running is idempotent (the index
lives between <!-- PDFX-INDEX:START/END --> markers and is replaced).

Requires: pypdf (`pip install pypdf`) and the sibling render.mjs + Google Chrome.
"""
import json, re, subprocess, sys, tempfile
from pathlib import Path
from pypdf import PdfReader

HERE = Path(__file__).resolve().parent
RENDER = HERE / "render.mjs"

STYLE = """<style>
/* injected by the pdf skill's add_index.py */
.pdfx-index { break-before: page; font-family: inherit; }
.pdfx-index h2 { margin: 0 0 6pt; }
.pdfx-intro { font-size: 10.5pt; color: #51616e; margin: 0 0 8pt; }
.pdfx-cols { column-count: 2; column-gap: 26pt; }
.pdfx-letter { font-weight: 700; font-size: 10.5pt; color: #0e5f74;
  margin: 9pt 0 3pt; break-after: avoid; break-inside: avoid; }
.pdfx-letter:first-child { margin-top: 0; }
.pdfx-row { display: flex; align-items: baseline; font-size: 10pt;
  margin-bottom: 3pt; break-inside: avoid; }
.pdfx-dots { flex: 1 1 auto; margin: 0 5px; border-bottom: 1px dotted #b4c3cb;
  position: relative; top: -3px; }
.pdfx-pg { font-variant-numeric: tabular-nums; color: #40505c; white-space: nowrap; }
</style>"""


def norm(s: str) -> str:
    s = s.lower()
    for a, b in [("’", "'"), ("‘", "'"), ("“", '"'), ("”", '"'), ("—", "-"), ("–", "-")]:
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s)


def render(html: Path, out: Path):
    subprocess.run(["node", str(RENDER), str(html), str(out)], check=True)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print(__doc__)
        sys.exit(2)
    doc = Path(args[0]).resolve()
    entries = json.loads(Path(args[1]).read_text(encoding="utf-8"))
    out = Path(next((args[i + 1] for i, a in enumerate(args) if a == "--out"), doc.with_suffix(".pdf")))
    insert_before = next((args[i + 1] for i, a in enumerate(args) if a == "--insert-before"), None)
    title = next((args[i + 1] for i, a in enumerate(args) if a == "--title"), "Index")

    html = doc.read_text(encoding="utf-8")
    html = re.sub(r"<!-- PDFX-INDEX:START -->.*?<!-- PDFX-INDEX:END -->\n?", "", html, flags=re.S)
    doc.write_text(html, encoding="utf-8")

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tf:
        body_pdf = Path(tf.name)
    render(doc, body_pdf)
    pages = [norm(p.extract_text() or "") for p in PdfReader(str(body_pdf)).pages]
    body_pdf.unlink(missing_ok=True)

    resolved, missing = [], []
    for label, phrase in entries:
        pg = next((i + 1 for i, t in enumerate(pages) if norm(phrase) in t), None)
        (missing.append((label, phrase)) if pg is None else resolved.append((label, pg)))
    for label, phrase in missing:
        print(f"!! not found (fix phrase): {label!r} -> {phrase!r}", file=sys.stderr)
    resolved.sort(key=lambda x: x[0].lower())

    rows, last = [], None
    for label, pg in resolved:
        c = label[0].upper()
        b = c if c.isalpha() else "#"
        if b != last:
            rows.append(f'    <div class="pdfx-letter">{b}</div>')
            last = b
        esc = label.replace("&", "&amp;").replace("<", "&lt;")
        rows.append(f'    <div class="pdfx-row"><span>{esc}</span>'
                    f'<span class="pdfx-dots"></span><span class="pdfx-pg">{pg}</span></div>')

    section = (
        "<!-- PDFX-INDEX:START -->\n" + STYLE + "\n"
        f'<section class="pdfx-index">\n  <h2>{title}</h2>\n'
        '  <p class="pdfx-intro">Page numbers refer to the printed document.</p>\n'
        '  <div class="pdfx-cols">\n' + "\n".join(rows) + "\n  </div>\n</section>\n"
        "<!-- PDFX-INDEX:END -->\n"
    )

    anchor = insert_before or ("<footer" if "<footer" in html else "</body>")
    html = html.replace(anchor, section + "\n" + anchor, 1)
    doc.write_text(html, encoding="utf-8")

    render(doc, out)
    print(f"index: {len(resolved)} entries, {len(missing)} missing -> {out}")


if __name__ == "__main__":
    main()
