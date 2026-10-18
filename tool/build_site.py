"""Render docs/legal/*.md into site/*.html (tiny markdown subset, no deps). Leaves the landing page alone.

Usage: python3 tool/build_site.py .
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
PAGES = [
    ("PRIVACY.md", "privacy.html", "Datenschutz"),
    ("TERMS.md", "terms.html", "Nutzungsbedingungen"),
    ("IMPRINT.md", "imprint.html", "Impressum"),
    ("DELETE_ACCOUNT.md", "delete-account.html", "Konto löschen"),
]


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)", r"<em>\1</em>", text)
    return text


def render(md: str) -> tuple[str, str]:
    out, para, lst, title = [], [], None, ""

    def flush_para():
        if para:
            out.append("<p>" + "<br>\n".join(inline(l) for l in para) + "</p>")
            para.clear()

    def flush_list():
        nonlocal lst
        if lst:
            tag, items = lst
            out.append(f"<{tag}>" + "".join(f"<li>{inline(i)}</li>" for i in items) + f"</{tag}>")
            lst = None

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line:
            flush_para(); flush_list(); continue
        if line.startswith("# "):
            flush_para(); flush_list()
            title = line[2:].strip()
            out.append(f"<h1>{inline(title)}</h1>")
        elif line.startswith("## "):
            flush_para(); flush_list()
            out.append(f"<h2>{inline(line[3:].strip())}</h2>")
        elif line.startswith("> "):
            flush_para(); flush_list()
            out.append(f'<p class="draft">{inline(line[2:].strip())}</p>')
        elif re.match(r"^- ", line):
            flush_para()
            if not lst or lst[0] != "ul":
                flush_list(); lst = ("ul", [])
            lst[1].append(line[2:].strip())
        elif re.match(r"^\d+\. ", line):
            flush_para()
            if not lst or lst[0] != "ol":
                flush_list(); lst = ("ol", [])
            lst[1].append(re.sub(r"^\d+\. ", "", line).strip())
        else:
            flush_list()
            para.append(line.strip())
    flush_para(); flush_list()
    return title, "\n".join(out)


def page(title: str, body: str) -> str:
    short = title.split(" — ")[0]
    title = short if short == "Booksquad" else f"{short} – Booksquad"
    nav = " · ".join(f'<a href="{href}">{label}</a>' for _, href, label in PAGES)
    return f"""<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<header><a class="brand" href="index.html">BOOKSQUAD</a></header>
<main>
{body}
</main>
<footer>{nav}</footer>
</body>
</html>
"""


def main():
    site = ROOT / "site"
    site.mkdir(exist_ok=True)
    for src, dst, _ in PAGES:
        title, body = render((ROOT / "docs/legal" / src).read_text(encoding="utf-8"))
        (site / dst).write_text(page(title, body), encoding="utf-8")
    # site/index.html is the hand-written landing page, not generated.


main()
