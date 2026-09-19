#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Check that every RFD document has the shape the corpus already uses.

The rules here were measured, not recalled. Each one was run against all 116
RFDs first, and only the rules that hold with no exception became checks. The
counts behind each decision, including the two conventions that were measured
and deliberately not gated, are in RFD 1124.

Every check reads a CommonMark AST rather than the bytes. That is not
decoration. The regex gate beside this one looks for `RFD 0123` in the raw
text, and an RFD wraps its prose at about 72 columns, so a citation split
across a line break was invisible to it. The AST joins a paragraph's inline
text before matching, which is the quantity the reader sees. On the corpus as
it stood, the byte scan found 3 unmigrated citations and this one found 37.

Run --self-test to see each check reject a known-bad input, because a check
that passes on broken input certifies the defect instead of catching it.
"""
import os
import re
import sys

from markdown_it import MarkdownIt

MD = MarkdownIt("commonmark")

ORG = "1"
DIR_RE = re.compile(r"^([12][0-9]{3})-[a-z0-9-]+$")
RFD_ROOT = "rfd"
TITLE_RE = re.compile(r"^RFD ([0-9]{4}): (\S.*)$")
DETAILS_TITLE_RE = re.compile(r"^RFD ([0-9]{4}) details: (\S.*)$")
# A state list in RFD 1000's own prose, so the gate and the document cannot
# drift apart. "a state: a, b, or c" is the sentence it parses.
STATE_LIST_RE = re.compile(r"has a state:\s*([a-z,\s]+?)\.", re.S)
# The README length bound, also read out of RFD 1000 rather than held here.
LIMIT_RE = re.compile(r"stays at (\d+) lines or fewer")
# Two numbering schemes have been withdrawn, so two citation forms are stale.
# The first began with 0, and no organization digit is 0. The second was
# hexadecimal, and only a hex serial carries a letter.
# The whitespace class is what the byte-level scan could not spell.
OLD_CITE_RE = re.compile(r"\bRFD\s+(0\d{3})\b")
HEX_CITE_RE = re.compile(r"\bRFD\s+([1-9][0-9a-f]{0,2}[a-f][0-9a-f]*)\b")
CITE_RE = re.compile(r"\bRFD\s+([0-9]{4})\b")
# The register's own reader, so the two gates cannot disagree about which
# serials exist. A deleted serial stays citable, so both tables count.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util as _ilu

_spec = _ilu.spec_from_file_location(
    "rfd_serials", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "check-rfd-serials.py"))
_serials = _ilu.module_from_spec(_spec)
_spec.loader.exec_module(_serials)

# The order these carry when present. Extra headings may sit between them.
SPINE = ("Decision", "Problem", "References", "Related")
# A retracted decision renames its own heading, so the match is a prefix.
# RFD 1067's "Decision, as published and now retracted" is the case.
REQUIRED = "Decision"
# A moved RFD develops elsewhere and states only where. Both of them carry no
# Decision, which is the whole point of the state.
NO_DECISION_STATES = {"moved"}


def blocks(tokens):
    """Top-level block opens, in document order."""
    return [t for t in tokens if t.level == 0 and t.type.endswith("_open")]


def headings(tokens):
    """(level, text, line) for every heading, text taken from the AST."""
    out = []
    for i, t in enumerate(tokens):
        if t.type == "heading_open":
            out.append((int(t.tag[1]), tokens[i + 1].content, t.map[0] + 1))
    return out


def inline_text(tokens):
    """Every inline run, soft breaks collapsed to one space.

    This is the string a reader sees. A citation wrapped over two source
    lines is one citation here, and is two unrelated tokens to a byte scan.
    """
    out = []
    for t in tokens:
        if t.type != "inline":
            continue
        parts = [c.content for c in (t.children or []) if c.type in ("text", "code_inline")]
        out.append(re.sub(r"\s+", " ", " ".join(parts)))
    return out


def _conventions_text(root):
    p = os.path.join(root, "rfd", "1000-conventions", "README.md")
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as fh:
        return " ".join(inline_text(MD.parse(fh.read())))


def parse_states(root):
    """Read the valid states out of RFD 1000, not out of this file."""
    text = _conventions_text(root)
    if text is None:
        return None
    m = STATE_LIST_RE.search(text)
    if not m:
        return None
    words = [w.strip() for w in m.group(1).split(",")]
    # The last item reads "or moved". The conjunction is prose, not a state.
    words = [re.sub(r"^or\s+", "", w) for w in words]
    return {w for w in words if w}


def parse_limit(root):
    """Read the README length bound out of RFD 1000, for the same reason.

    The bound is 40 and the corpus lands 12 READMEs exactly on it, so it is
    inclusive. RFD 1000 said "under 40" until this gate measured that, and
    RFD 1124 records the correction rather than the gate carrying an
    off-by-one to match prose nobody had checked.
    """
    text = _conventions_text(root)
    if text is None:
        return None
    m = LIMIT_RE.search(text)
    return int(m.group(1)) if m else None


def known_numbers(root, dirs):
    """A citation resolves to a serial the register lists.

    The deleted serials matter. RFD 1070 and RFD 1064 removed six speculative
    RFDs and still cite them by number. Requiring a directory would reject the
    citation that records the deletion.

    SERIALS.usda is the one place those numbers live, and `check-rfd-serials.py`
    holds it against the tree. This gate borrows that file's reader rather than
    parsing the register a second way, so the two cannot disagree about which
    numbers exist.
    """
    nums = {d[:4] for d in dirs}
    # Every SERIALS*.usda register in the repo root contributes: SERIALS.usda
    # holds the site-1 (documents) 1xxx series, SERIALS-vsekai-fabric.usda
    # holds the site-2 2xxx series reactivated 2026-08-31 per CLAUDE.md.
    for entry in sorted(os.listdir(root)):
        if not (entry == "SERIALS.usda" or (entry.startswith("SERIALS-")
                                             and entry.endswith(".usda"))):
            continue
        with open(os.path.join(root, entry), encoding="utf-8") as fh:
            allocated, deleted = _serials.read(fh.read())
        nums |= set(allocated) | set(deleted)
    return nums


def check_title(name, num, tokens, regex, kind):
    problems = []
    hs = headings(tokens)
    h1s = [h for h in hs if h[0] == 1]
    if len(h1s) != 1:
        problems.append(f"{name}: has {len(h1s)} level-1 headings, and needs exactly 1")
        return problems
    first = blocks(tokens)[0] if blocks(tokens) else None
    if first is None or first.type != "heading_open" or first.tag != "h1":
        problems.append(f"{name}: does not open with its title heading")
    m = regex.match(h1s[0][1])
    if not m:
        problems.append(f"{name}: title is not '{kind}', it is {h1s[0][1]!r}")
    elif m.group(1) != num:
        problems.append(f"{name}: title says {m.group(1)}, directory says {num}")
    return problems


def check_preamble(name, tokens, states):
    """The paragraph under the title carries State, then Feature, then Scope."""
    problems = []
    bs = blocks(tokens)
    if len(bs) < 2 or bs[1].type != "paragraph_open":
        problems.append(f"{name}: no metadata paragraph under the title")
        return problems, None
    lines = inline_text(tokens)
    body = lines[1] if len(lines) > 1 else ""
    keys = strong_fields(tokens, bs[1])
    if not keys:
        problems.append(f"{name}: metadata paragraph carries no '**Key:** value' field")
        return problems, None
    if keys[0] != "State":
        problems.append(f"{name}: first metadata field is {keys[0]!r}, and must be 'State'")
    allowed = ["State", "Feature", "Scope"]
    for k in keys:
        if k not in allowed:
            problems.append(f"{name}: metadata field {k!r} is not one of {allowed}")
    if len(set(keys)) != len(keys):
        problems.append(f"{name}: a metadata field is repeated: {keys}")
    ranks = [allowed.index(k) for k in keys if k in allowed]
    if ranks != sorted(ranks):
        problems.append(f"{name}: metadata fields are out of order: {keys}")
    m = re.search(r"State:\s*(\S+)", body)
    state = m.group(1) if m else None
    if state is None:
        problems.append(f"{name}: State has no value")
    elif states is not None and state not in states:
        problems.append(
            f"{name}: state {state!r} is not one RFD 1000 lists: {sorted(states)}"
        )
    return problems, state


def strong_fields(tokens, block):
    """The `**Key:**` names in one paragraph, read off the AST.

    A field is bold text ending in a colon. The AST already separated that
    markup from the value beside it, so nothing here re-parses asterisks.
    """
    keys = []
    for t in tokens:
        if t.type != "inline" or t.map != block.map:
            continue
        depth = 0
        for c in (t.children or []):
            if c.type == "strong_open":
                depth = 1
            elif c.type == "strong_close":
                depth = 0
            elif depth and c.type == "text" and c.content.rstrip().endswith(":"):
                keys.append(c.content.rstrip().rstrip(":").strip())
    return keys


def check_length(name, source, limit):
    """RFD 1000 keeps a README to the problem and the decision.

    The count is a proxy for that, and it is the proxy RFD 1000 states, so it
    is the one enforced. What overruns it is a measurement, a walkthrough or a
    retraction, and each of those has a sibling file to live in.
    """
    if limit is None:
        return []
    n = len(source.splitlines())
    if n > limit:
        return [f"{name}: is {n} lines, and the limit RFD 1000 gives is {limit}"]
    return []


def check_sections(name, tokens, state):
    problems = []
    h2 = [h[1] for h in headings(tokens) if h[0] == 2]
    seen = []
    for text in h2:
        for canon in SPINE:
            if text == canon or text.startswith(canon + ","):
                seen.append(canon)
                break
    if len(set(seen)) != len(seen):
        problems.append(f"{name}: a spine section appears twice: {seen}")
    ranks = [SPINE.index(s) for s in seen]
    if ranks != sorted(ranks):
        problems.append(
            f"{name}: sections run {seen}, and the order is {list(SPINE)}"
        )
    if REQUIRED not in seen and state not in NO_DECISION_STATES:
        problems.append(f"{name}: has no '## {REQUIRED}' section")
    return problems


def check_citations(name, tokens, nums):
    problems = []
    for line in inline_text(tokens):
        for m in OLD_CITE_RE.finditer(line):
            problems.append(f"{name}: cites RFD {m.group(1)} in the first decimal form")
        for m in HEX_CITE_RE.finditer(line):
            problems.append(f"{name}: cites RFD {m.group(1)} in the withdrawn hex form")
        for m in CITE_RE.finditer(line):
            n = m.group(1)
            if n.startswith("0"):
                continue  # already reported above
            if n[0] != ORG:
                # Another site's number. This gate owns this site's serials, and
                # the composed layer that holds every site's is workspace-scoped,
                # so resolving it here is not possible from one checkout.
                # `check_pen_66606.py` is where cross-site numbers are held.
                continue
            if n not in nums:
                problems.append(
                    f"{name}: cites RFD {n}, which the register does not list"
                )
    return problems


SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def check_skill(name, source):
    """RFD 1000: a SKILL.md carries frontmatter with a name and a description.

    The name is what somebody types and the description is when to reach for it, so an
    empty description is the failure that matters here: a skill nobody can tell apart
    from another skill is a skill nobody invokes on purpose.

    Read line by line rather than with a regex over the whole file, because the fence is
    a line and treating it as a substring finds the "---" inside a table's rule row.
    """
    problems = []
    lines = source.splitlines()
    if not lines or lines[0].strip() != "---":
        return [f"{name}: no frontmatter, and RFD 1000 asks for a name and a description"]
    closing = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if closing is None:
        return [f"{name}: the frontmatter is never closed"]

    fields = {}
    for line in lines[1:closing]:
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    for key in ("name", "description"):
        if not fields.get(key):
            problems.append(f"{name}: the frontmatter states no {key}")
    if fields.get("name") and not SKILL_NAME_RE.match(fields["name"]):
        problems.append(f"{name}: name {fields['name']!r} is not kebab-case")
    return problems


def check(root):
    problems = []
    dirs = sorted(
        d for d in os.listdir(os.path.join(root, "rfd"))
        if DIR_RE.match(d) and os.path.isdir(os.path.join(root, "rfd", d))
    )
    if not dirs:
        problems.append("no RFD directories found, which is never correct here")
        return problems

    states = parse_states(root)
    if states is None:
        problems.append(
            "RFD 1000 no longer states its list of states, so this gate cannot read it"
        )
    limit = parse_limit(root)
    if limit is None:
        problems.append(
            "RFD 1000 no longer states its README line limit, so this gate cannot read it"
        )
    nums = known_numbers(root, dirs)

    for d in dirs:
        num = DIR_RE.match(d).group(1)
        readme = os.path.join(root, "rfd", d, "README.md")
        if not os.path.exists(readme):
            problems.append(f"{d}/README.md: missing")
            continue
        with open(readme, encoding="utf-8") as fh:
            source = fh.read()
        # Skip a leading YAML frontmatter block if present; a README doubling as a
        # Claude Code skill carries `---\n<yaml>\n---` before the RFD title. The
        # frontmatter is skill metadata for the harness; the RFD title, preamble
        # and sections start after it. Same skip on the length count.
        stripped = source
        if source.startswith("---\n"):
            end = source.find("\n---\n", 4)
            if end >= 0:
                stripped = source[end + 5:]
        toks = MD.parse(stripped)
        name = f"{d}/README.md"
        problems += check_length(name, stripped, limit)
        problems += check_title(name, num, toks, TITLE_RE, "RFD <num>: <title>")
        pre, state = check_preamble(name, toks, states)
        problems += pre
        problems += check_sections(name, toks, state)
        problems += check_citations(name, toks, nums)

        skill = os.path.join(root, "apparatus", d, "SKILL.md")
        if os.path.exists(skill):
            with open(skill, encoding="utf-8") as fh:
                problems += check_skill(f"{d}/SKILL.md", fh.read())

        details = os.path.join(root, "rfd", d, "DETAILS.md")
        if os.path.exists(details):
            # RFD 1000: a README moves the long material out and names where
            # it went. A sibling nothing points at is a file nobody opens.
            if "DETAILS.md" not in " ".join(inline_text(toks)):
                problems.append(f"{name}: has a DETAILS.md and never names it")
            with open(details, encoding="utf-8") as fh:
                dtoks = MD.parse(fh.read())
            dname = f"{d}/DETAILS.md"
            problems += check_title(
                dname, num, dtoks, DETAILS_TITLE_RE, "RFD <num> details: <title>"
            )
            problems += check_citations(dname, dtoks, nums)

    problems += check_loose_markdown(root, nums)
    return problems


def check_loose_markdown(root, nums):
    """The repository's own markdown carries citations too, and nothing read it.

    The RFD loop above walks `NNNN-slug/` and stops there. `CLAUDE.md`,
    `PITFALLS.md`, `BLOCKLIST.md` and the `logbook-*.md` entries sit at the
    root, they cite RFDs constantly, and the decimal renumbering left 25
    citations in the first form across three of them. Nothing failed. They were
    found by hand, which is the detection method this repository exists to
    replace.

    Only citations are checked. These files are not RFDs and have no title,
    preamble or section spine to hold them to.
    """
    problems = []
    loose = [(root, n) for n in os.listdir(root)]
    lb = os.path.join(root, "logbook")
    if os.path.isdir(lb):
        loose += [(lb, n) for n in os.listdir(lb)]
    for base, name in sorted(loose, key=lambda t: t[1]):
        if not name.endswith(".md") or not os.path.isfile(os.path.join(base, name)):
            continue
        with open(os.path.join(base, name), encoding="utf-8") as fh:
            toks = MD.parse(fh.read())
        problems += check_citations(name, toks, nums)
    return problems


GOOD_README = """# RFD 1001: A title

**State:** published
**Feature:** a feature

## Decision

A decision.

## Problem

A problem. RFD 1002 is the neighbour.

## Related

See `DETAILS.md` for the rest.
"""
GOOD_DETAILS = "# RFD 1001 details: the rest\n\nProse.\n"
# The gate reads the citable numbers out of the register, so the fixture tree
# carries one. RFD 1002 is deleted here, and the good README cites it.
REGISTER = _serials.GOOD
GOOD_CONVENTIONS = """# RFD 1000: Conventions

**State:** published
**Scope:** all files

## Decision

Each RFD has a state: prediscussion, ideation, discussion, published,
committed, abandoned, or moved.

Each RFD's `README.md` stays at 40 lines or fewer.
"""


def self_test():
    import shutil
    import tempfile

    def build(tmp, readme=GOOD_README, details=GOOD_DETAILS, deleted=None, skill=None):
        for n, body in (("1000-conventions", GOOD_CONVENTIONS), ("1001-a-slug", readme)):
            os.makedirs(os.path.join(tmp, "rfd", n))
            with open(os.path.join(tmp, "rfd", n, "README.md"), "w", encoding="utf-8") as fh:
                fh.write(body)
        if details is not None:
            with open(os.path.join(tmp, "rfd", "1001-a-slug", "DETAILS.md"), "w", encoding="utf-8") as fh:
                fh.write(details)
        if skill is not None:
            os.makedirs(os.path.join(tmp, "apparatus", "1001-a-slug"))
            with open(os.path.join(tmp, "apparatus", "1001-a-slug", "SKILL.md"), "w", encoding="utf-8") as fh:
                fh.write(skill)
        with open(os.path.join(tmp, "SERIALS.usda"), "w", encoding="utf-8") as fh:
            fh.write(deleted if deleted is not None else REGISTER)

    wrapped = GOOD_README.replace("RFD 1002 is the neighbour.", "RFD\n0001 is the neighbour.")
    cases = [
        ("a clean tree passes", {}, False),
        ("title number disagrees with the directory",
         {"readme": GOOD_README.replace("# RFD 1001:", "# RFD 1003:")}, True),
        ("the title is not the first block",
         {"readme": "Loose prose first.\n\n" + GOOD_README}, True),
        ("a second level-1 heading",
         {"readme": GOOD_README + "\n# RFD 1001: Again\n"}, True),
        ("no metadata paragraph",
         {"readme": GOOD_README.replace("**State:** published\n**Feature:** a feature\n\n", "")}, True),
        ("a state RFD 1000 does not list",
         {"readme": GOOD_README.replace("published", "in-progress")}, True),
        ("a state RFD 1000 does not list, planted as 'parked'",
         {"readme": GOOD_README.replace("published", "parked")}, True),
        ("Scope written before Feature",
         {"readme": GOOD_README.replace("**Feature:** a feature", "**Scope:** x\n**Feature:** y")}, True),
        ("an unknown metadata field",
         {"readme": GOOD_README.replace("**Feature:** a feature", "**Owner:** somebody")}, True),
        ("no Decision section",
         {"readme": GOOD_README.replace("## Decision\n\nA decision.\n\n", "")}, True),
        ("Problem written before Decision",
         {"readme": GOOD_README.replace("## Decision\n\nA decision.\n\n## Problem\n\nA problem. RFD 1002 is the neighbour.\n\n",
                                        "## Problem\n\nA problem. RFD 1002 is the neighbour.\n\n## Decision\n\nA decision.\n\n")}, True),
        ("a decimal citation split across a line break", {"readme": wrapped}, True),
        ("a citation that resolves nowhere",
         {"readme": GOOD_README.replace("RFD 1002", "RFD 1153")}, True),
        ("a hex citation, which is the withdrawn form",
         {"readme": GOOD_README.replace("RFD 1002", "RFD 100a")}, True),
        ("a number the register does not list",
         {"deleted": REGISTER.replace("custom int[] serial = [1002]",
                                      "custom int[] serial = [1003]")}, True),
        ("a DETAILS.md the README never names",
         {"readme": GOOD_README.replace("See `DETAILS.md` for the rest.", "Nothing here.")}, True),
        ("a DETAILS.md titled for another RFD",
         {"details": "# RFD 1009 details: the rest\n"}, True),
        ("a SKILL.md with no frontmatter", {"skill": '# just a heading\n'}, True),
        ("a SKILL.md with an empty description",
         {"skill": '---\nname: a-skill\ndescription:\n---\n\nBody.\n'}, True),
        ("a SKILL.md whose name is not kebab-case",
         {"skill": '---\nname: A Skill\ndescription: when to reach for it\n---\n\nBody.\n'}, True),
        ("a well-formed SKILL.md is accepted", {"skill": '---\nname: a-skill\ndescription: when to reach for it\n---\n\nBody.\n'}, False),
        ("a README past the line limit RFD 1000 gives",
         {"readme": GOOD_README + "\nfiller\n" * 40}, True),
    ]
    ok = True
    print("self-test: each known-bad input must be rejected")
    for label, kw, should_fail in cases:
        tmp = tempfile.mkdtemp()
        try:
            build(tmp, **kw)
            failed = bool(check(tmp))
            if failed != should_fail:
                ok = False
            mark = "ok " if failed == should_fail else "BAD"
            print(f"  {mark} {label}: {'rejected' if failed else 'accepted'}")
        finally:
            shutil.rmtree(tmp)
    return 0 if ok else 1


def _changed_rfd_prefixes(root, base):
    """RFD directory basenames (`<num>-<slug>`) touched between `base` and HEAD.

    Used by CI to enforce the gate on what a PR modified rather than the
    whole tree. The full-tree sweep still runs from `check_anti_entropy.py`,
    so nothing that used to be seen goes unseen; a pre-existing finding just
    stops blocking every subsequent PR that did not introduce it.
    """
    import subprocess
    try:
        r = subprocess.run(["git", "-C", root, "diff", "--name-only",
                            f"{base}...HEAD"],
                           capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError:
        return None
    prefixes = set()
    for path in r.stdout.splitlines():
        if not path.startswith("rfd/"):
            continue
        segs = path.split("/")
        name = segs[1][:-4] if len(segs) == 2 and segs[1].endswith(".exs") else segs[1]
        if len(segs) >= 2 and DIR_RE.match(name):
            prefixes.add(name)
    return prefixes


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    found = check(root)
    if "--all" in sys.argv:
        # Explicit alias for the default full-tree mode. Named so a caller
        # that wants the SPINE backlog visible on demand does not have to
        # know the default; also refuses to combine with --changed.
        if "--changed" in sys.argv:
            sys.exit("FAIL --all and --changed are mutually exclusive")
        print(f"full mode: {len(rfd_dirs := sorted(d for d in os.listdir(os.path.join(root, RFD_ROOT)) if DIR_RE.match(d)))} RFD dir(s) scanned")
    if "--changed" in sys.argv:
        base = sys.argv[sys.argv.index("--changed") + 1]
        touched = _changed_rfd_prefixes(root, base)
        if touched is None:
            print(f"cannot compute changed set against {base!r}; running full check")
        else:
            found = [line for line in found
                     if any(line.startswith(f"{d}/") for d in touched)]
            print(f"scoped to {len(touched)} changed RFD(s): {sorted(touched)}")
    for line in found:
        print(line)
    print(f"{len(found)} problems")
    sys.exit(1 if found else 0)
