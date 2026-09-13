#!/usr/bin/env python3
"""Build a text corpus from a folder of PDFs, for grounding a skill.

    python3 build-corpus.py ~/papers -o references/corpus
    python3 build-corpus.py ~/papers -o references/corpus --chunk 40000

Writes one .txt per PDF plus a _manifest.json, and runs a ligature check on the output.

Why this script exists rather than `pdftotext`:

  `pdftotext` drops fi/fl/ff ligatures from many academic PDFs. "fitness" comes out as
  " tness", "specified" as "speci ed", "effects" as "eects". The mangled words are exactly
  the ones you would search the corpus for, so the corpus reads fine and is useless. PyMuPDF
  handles them correctly. This was measured, not assumed: on one 500-page manual, PyMuPDF
  gave 1446 correct instances of "fitness" and zero mangled; pdftotext mangled about 70%.

  The check at the end of this run is what tells you whether your PDFs are the kind that
  break. If it reports mangled words, PyMuPDF has not saved you and you need a better
  source: see `--help-source`.

Requires: pip install pymupdf
"""
import argparse, json, os, re, sys, unicodedata

SOURCE_NOTE = """
Prefer source over rendered output.

If the document exists as LaTeX, Markdown, reStructuredText or HTML anywhere, build from that
instead of the PDF. Extraction from a PDF is always a reconstruction, and for older documents
it is a lossy one: Type 1 LaTeX PDFs from the 1990s and 2000s often carry no usable character
map at all, and then *every* extractor drops ligatures, PyMuPDF included.

Two failures worth knowing about, because they are silent:

  * Ligature loss. "confidence" -> "condence", "effects" -> "eects". Greppable terms become
    ungreppable. The check this script runs is for exactly this.

  * De-TeXing that destroys meaning. Stripping \\mid turns E(w | z), a conditional
    expectation, into E(w z), a product. A naive \\to -> "->" replacement rewrites \\theta as
    "->heta", deleting the most important symbol in the corpus. Map control words with a
    non-letter boundary, and map the specific ones (Greek, relations, \\frac) before any
    generic strip.

If the only available form is a PDF that fails the check, say so in the skill's own notes.
A corpus you cannot trust is worse than no corpus, because the model will cite it.
"""

# Words whose mangled forms are unambiguous evidence of ligature loss.
LIGATURE_PROBES = [
    ("fitness", ["tness", "f tness"]),
    ("specified", ["specied", "speci ed"]),
    ("effect", ["eect", "e ect"]),
    ("confidence", ["condence", "con dence"]),
    ("difference", ["dierence", "di erence"]),
    ("first", ["rst", "f rst"]),
    ("coefficient", ["coecient", "coe cient"]),
]


def extract(path):
    import fitz  # pymupdf
    doc = fitz.open(path)
    pages = []
    for i, page in enumerate(doc, 1):
        pages.append(page.get_text("text"))
    doc.close()
    return pages


def clean(text):
    # Normalize unicode, join words broken across a line by a hyphen, collapse runs of
    # blank lines. Deliberately conservative: this is a search corpus, not a reading copy.
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"(\w)-\n(\w)", r"\1\2", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def ligature_report(text):
    """Return (intact, mangled) counts per probe word, for words that appear at all."""
    low = text.lower()
    rows = []
    for good, bads in LIGATURE_PROBES:
        n_good = len(re.findall(r"\b" + re.escape(good), low))
        n_bad = sum(len(re.findall(r"\b" + re.escape(b) + r"\b", low)) for b in bads)
        if n_good or n_bad:
            rows.append((good, n_good, n_bad))
    return rows


def chunk_text(text, size):
    """Split on paragraph boundaries into pieces of at most `size` characters."""
    if size <= 0 or len(text) <= size:
        return [text]
    out, buf = [], ""
    for para in text.split("\n\n"):
        if buf and len(buf) + len(para) + 2 > size:
            out.append(buf); buf = para
        else:
            buf = f"{buf}\n\n{para}" if buf else para
    if buf:
        out.append(buf)
    return out


def main():
    ap = argparse.ArgumentParser(description="Build a grounding corpus from PDFs.")
    ap.add_argument("src", nargs="?", help="folder of PDFs (searched recursively)")
    ap.add_argument("-o", "--out", default="corpus", help="output folder")
    ap.add_argument("--chunk", type=int, default=0,
                    help="split files longer than this many characters (0 = never)")
    ap.add_argument("--help-source", action="store_true",
                    help="explain why source beats rendered output, and exit")
    args = ap.parse_args()

    if args.help_source:
        print(SOURCE_NOTE.strip()); return 0
    if not args.src:
        ap.error("give a folder of PDFs, or --help-source")

    try:
        import fitz  # noqa: F401
    except ImportError:
        print("This needs PyMuPDF:  pip install pymupdf", file=sys.stderr)
        print("Do not substitute pdftotext — see --help-source.", file=sys.stderr)
        return 1

    pdfs = []
    for root, _, files in os.walk(args.src):
        for f in sorted(files):
            if f.lower().endswith(".pdf"):
                pdfs.append(os.path.join(root, f))
    if not pdfs:
        print(f"No PDFs under {args.src}", file=sys.stderr); return 1

    os.makedirs(args.out, exist_ok=True)
    manifest, suspect = [], []

    for path in pdfs:
        stem = re.sub(r"[^A-Za-z0-9._-]+", "_", os.path.splitext(os.path.basename(path))[0])[:120]
        try:
            pages = extract(path)
        except Exception as e:
            print(f"  FAILED  {os.path.basename(path)}: {e}", file=sys.stderr)
            continue
        text = clean("\n\n".join(pages))
        rows = ligature_report(text)
        bad = sum(b for _, _, b in rows)

        chunks = chunk_text(text, args.chunk)
        written = []
        for i, c in enumerate(chunks, 1):
            name = f"{stem}.txt" if len(chunks) == 1 else f"{stem}.part{i:02d}.txt"
            with open(os.path.join(args.out, name), "w", encoding="utf-8") as fh:
                fh.write(c)
            written.append(name)

        manifest.append({
            "source": os.path.relpath(path, args.src),
            "files": written,
            "pages": len(pages),
            "chars": len(text),
            "ligature_mangled": bad,
        })
        flag = f"  ** {bad} mangled **" if bad else ""
        print(f"  {os.path.basename(path):<60} {len(pages):>4}p  {len(text):>8}c{flag}")
        if bad:
            suspect.append((os.path.basename(path), rows))

    with open(os.path.join(args.out, "_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump({"source_dir": os.path.abspath(args.src), "documents": manifest}, fh, indent=2)

    print(f"\n{len(manifest)} document(s) -> {args.out}/")

    if suspect:
        print("\nLIGATURE CHECK FAILED for:")
        for name, rows in suspect:
            print(f"  {name}")
            for good, n_good, n_bad in rows:
                if n_bad:
                    print(f"    {good}: {n_good} intact, {n_bad} mangled")
        print("\nThis corpus is not yet trustworthy. Run --help-source.")
        return 2

    print("Ligature check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
