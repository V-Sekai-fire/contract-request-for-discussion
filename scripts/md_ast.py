# SPDX-License-Identifier: Apache-2.0 OR MIT
"""CommonMark structure for the gates that read markdown.

WHY THIS EXISTS. A gate that finds a table row with `line.startswith("|")`, a
section with `^### `, or a paragraph by splitting on blank lines is reading the
file as text rather than as the document a reader sees. Fenced code containing a
pipe is a table row to it, a shell prompt beginning `###` is a heading, and an
indented continuation is a new paragraph. Every one of those is a verdict made
on something nobody reads as prose.

markdown-it-py parses the same CommonMark the renderer does, so these helpers
answer with what the document means rather than what the bytes look like.

RFD SOURCES ARE ELIXIR. An `.exs` holds its prose in sigil heredocs, so those
bodies are pulled out and parsed as one document. A file with no heredoc
is parsed whole, which is what a `.md` needs.
"""

import re

from markdown_it import MarkdownIt

HEREDOC = re.compile(r'~S?"""(.*?)"""', re.DOTALL)


def _document(text):
    bodies = HEREDOC.findall(text)
    return "\n\n".join(bodies) if bodies else text


def tokens(text):
    return MarkdownIt("commonmark").enable("table").parse(_document(text))


def prose(text):
    """Text a reader reads: no code blocks, no urls, no html, no table pipes."""
    out = []
    for token in tokens(text):
        if token.type in ("fence", "code_block", "html_block"):
            continue
        if token.type != "inline":
            continue
        for child in token.children or ():
            if child.type == "text":
                out.append(child.content)
            elif child.type == "code_inline":
                out.append("code")
    return " ".join(out)


def headings(text, level=None):
    """(level, text) for every heading, in order."""
    found, want = [], None
    for token in tokens(text):
        if token.type == "heading_open":
            want = int(token.tag[1:])
        elif token.type == "inline" and want is not None:
            if level is None or want == level:
                found.append((want, token.content.strip()))
            want = None
    return found


def table_rows(text):
    """Every table body row, as a list of cell strings."""
    rows, row, cell, in_body = [], [], None, False
    for token in tokens(text):
        if token.type == "tbody_open":
            in_body = True
        elif token.type == "tbody_close":
            in_body = False
        elif in_body and token.type == "tr_open":
            row = []
        elif in_body and token.type == "tr_close":
            rows.append(row)
        elif in_body and token.type == "inline":
            row.append(token.content.strip())
    return rows


def paragraphs(text):
    """Paragraph text, with inline code kept so a name inside backticks survives."""
    out, want = [], False
    for token in tokens(text):
        if token.type == "paragraph_open":
            want = True
        elif token.type == "inline" and want:
            out.append(token.content)
            want = False
    return out


def first_paragraph(text):
    """The tagline: the first paragraph, not the first non-blank line."""
    for para in paragraphs(text):
        if para.strip():
            return " ".join(para.split())
    return ""
