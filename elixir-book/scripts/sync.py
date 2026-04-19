#!/usr/bin/env python3
"""
Mirror modules/ROOT/pages/elixir/ (the Elixir chapter of the main
book) into elixir-book/modules/ROOT/pages/ so Antora can render it
as a standalone site at /elixir/book/.

- Drops the leading `elixir/` path prefix. Files at
  `pages/elixir/iex.adoc` land as `pages/iex.adoc` in the mini-book,
  so URLs end up at /elixir/book/iex.html instead of the awkward
  /elixir/book/elixir/iex.html.
- Rewrites `xref:elixir/<x>.adoc` → `xref:<x>.adoc` in all copied
  files, preserving internal links between chapters.
- Skips `index.adoc` (it's a one-page include:: merge of every
  sub-chapter — the mini-book uses a sidebar instead, so we write
  our own minimal landing).

Generated files are gitignored; the one source of truth is the main
Elixir chapter under modules/ROOT/pages/elixir/.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path

SRC = Path("modules/ROOT/pages/elixir")
DST = Path("elixir-book/modules/ROOT/pages")

XREF_RE = re.compile(r"(xref|include):elixir/")


def main() -> None:
    # Wipe prior output so deleted source files don't linger.
    for existing in DST.glob("*"):
        if existing.is_dir():
            shutil.rmtree(existing)
        else:
            existing.unlink()
    DST.mkdir(parents=True, exist_ok=True)

    for src_file in SRC.rglob("*.adoc"):
        rel = src_file.relative_to(SRC)
        # Skip the main-book landing — it's an include::-heavy single
        # page; the mini-book's landing is written by hand below.
        if str(rel) == "index.adoc":
            continue
        dst_file = DST / rel
        dst_file.parent.mkdir(parents=True, exist_ok=True)
        content = src_file.read_text()
        content = XREF_RE.sub(r"\1:", content)
        dst_file.write_text(content)

    # Copy any non-adoc assets (rare here, but robust).
    for src_file in SRC.rglob("*"):
        if src_file.is_file() and src_file.suffix != ".adoc":
            rel = src_file.relative_to(SRC)
            dst_file = DST / rel
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)

    (DST / "index.adoc").write_text(LANDING)
    print(f"synced Elixir chapter -> {DST}/")


LANDING = """\
= Welcome
Stefan Wintermeyer <sw@wintermeyer-consulting.de>

This is the Elixir chapter from the
link:https://wintermeyer-consulting.de/phoenix/book/[_Elixir, Phoenix and
Ash Beginner's Guide_], split page-per-topic so each concept has its
own URL. If you want the full guide (Elixir, Phoenix, Ash, and
recipes), read it in the parent book.

Pick a topic from the sidebar.

If this is your first functional programming language you might want
to get a cup of coffee first. It might take a while to get used to
the functional programming paradigm. **It took me a long time too!**
"""


if __name__ == "__main__":
    main()
