#!/usr/bin/env python3
"""Extract text and hyperlink URIs from a resume PDF.

Usage: extract_pdf_links.py <resume.pdf>

Prints all hyperlink URIs found in the PDF (email, LinkedIn, GitHub, etc.),
with GitHub URLs flagged, followed by the full extracted text.
"""

import re
import sys
import zlib


def extract(pdf_path):
    data = open(pdf_path, "rb").read()
    uris = []
    texts = []
    for m in re.finditer(rb"stream\r?\n(.*?)endstream", data, re.S):
        try:
            d = zlib.decompress(m.group(1))
        except Exception:
            continue
        for u in re.findall(rb"/URI\s*\(([^)]*)\)", d):
            s = u.decode("latin-1", "ignore")
            if s and s not in uris:
                uris.append(s)
        for t in re.findall(rb"\((?:[^()\\]|\\.)*\)", d):
            s = t[1:-1].decode("latin-1", "ignore")
            if s.strip():
                texts.append(s)

    print("=== LINKS ===")
    for u in uris:
        marker = "  <-- GITHUB" if "github.com" in u.lower() else ""
        print(f"{u}{marker}")

    print("\n=== TEXT ===")
    print("\n".join(texts))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: extract_pdf_links.py <resume.pdf>")
    extract(sys.argv[1])
