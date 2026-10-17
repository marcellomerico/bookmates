#!/usr/bin/env python3
"""Checks every `text` block in docs/STORE_LISTING.md against the `(max N)` in its heading.

Usage: python3 tool/check_store_listing.py   (exit 1 if a text is too long)
"""
import pathlib
import re
import sys

doc = pathlib.Path(__file__).resolve().parent.parent / "docs" / "STORE_LISTING.md"
pattern = re.compile(r"^###[ \t]+([^\n]+?)[ \t]+\(max (\d+)\)[ \t]*$((?:(?!^###).)*?)^```text\n(.*?)^```", re.M | re.S)

failed = checked = 0
for title, limit, _, text in pattern.findall(doc.read_text(encoding="utf-8")):
    length = len(text.rstrip("\n"))  # stores count characters, not bytes
    ok = length <= int(limit)
    checked += 1
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'}  {length:>4}/{limit:<4} {title}")

assert checked, "no limited text blocks found"
sys.exit(1 if failed else 0)
