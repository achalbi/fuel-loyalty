#!/usr/bin/env python3
"""Regenerate docs/acefuels/*.html from the matching *.md, reusing the shared
template (head/topbar/footer) extracted from a reference .html file.

Faithful reproduction of the existing bespoke render:
  - python-markdown with `extra` (tables, fenced_code, ...) + `toc` (heading ids)
  - <table> wrapped in <div class="table-wrap">
  - ```mermaid fences -> <figure class="figure diagram"><figcaption>Diagram</figcaption><pre class="mermaid">...</pre></figure>
"""
import re
import sys
import pathlib
import markdown

DOCS = pathlib.Path("docs/acefuels")
REFERENCE = DOCS / "11-spec-litres-readings.html"  # complete file; template only
GEN_DATE = "2026-07-22"

ART_OPEN = '<article class="doc">'
ART_CLOSE = '</article>'

DOCFOOT = (
    '<div class="docfoot">\n'
    '  <span>Part of the <a href="index.html">AceFuels documentation set</a>.</span>\n'
    '  <span class="fnote">Generated from {crumb} &middot; {date}</span>\n'
    '</div>\n'
)


def split_template(ref_html: str):
    pre = ref_html[: ref_html.index(ART_OPEN) + len(ART_OPEN)] + "\n"
    post = ref_html[ref_html.index(ART_CLOSE):]
    # Blank out the per-file bits in the preamble.
    pre = re.sub(r"<title>.*?</title>", "<title>{{TITLE}}</title>", pre, flags=re.S)
    pre = re.sub(r'(<span class="crumb">).*?(</span>)', r"\1{{CRUMB}}\2", pre)
    return pre, post


def wrap_tables(html: str) -> str:
    return re.sub(r"<table>(.*?)</table>", r'<div class="table-wrap"><table>\1</table></div>', html, flags=re.S)


def mermaid_figures(html: str) -> str:
    # fenced_code renders ```mermaid as <pre><code class="language-mermaid">...</code></pre>
    pat = re.compile(r'<pre><code class="language-mermaid">(.*?)</code></pre>', re.S)
    return pat.sub(
        lambda m: '<figure class="figure diagram"><figcaption>Diagram</figcaption>'
                  '<pre class="mermaid">' + m.group(1) + "</pre></figure>",
        html,
    )


def render(md_path: pathlib.Path, pre: str, post: str, date: str) -> str:
    text = md_path.read_text()
    h1 = re.search(r"^#\s+(.+)$", text, re.M)
    title = (h1.group(1).strip() if h1 else md_path.stem) + " — AceFuels Docs"
    md = markdown.Markdown(extensions=["extra", "toc"], output_format="xhtml")
    body = md.convert(text)
    body = mermaid_figures(wrap_tables(body))
    # Cross-doc references (in hrefs AND prose) point at sibling .md files; the
    # HTML set uses .html. Rewrite only the numbered spec docs / index / README,
    # so paths like ../a7-prod-provisioning.md (no .html twin) are left intact.
    body = re.sub(r"\b(\d\d-[a-z0-9-]+|index|README)\.md\b", r"\1.html", body)
    docfoot = DOCFOOT.format(crumb=md_path.name, date=date)
    page = (pre.replace("{{TITLE}}", title).replace("{{CRUMB}}", md_path.name)
            + body + "\n" + docfoot + post)
    return page


def main(targets, date=GEN_DATE):
    pre, post = split_template(REFERENCE.read_text())
    for name in targets:
        md_path = DOCS / (name if name.endswith(".md") else name + ".md")
        html_path = md_path.with_suffix(".html")
        html_path.write_text(render(md_path, pre, post, date))
        print("wrote", html_path)


if __name__ == "__main__":
    main(sys.argv[1:])
