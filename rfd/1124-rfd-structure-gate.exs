# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1124. `mix rfd.render` renders rfd/1124-rfd-structure-gate/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1124 do
  use RFD.DSL

  rfd 1124, "The RFD structure gate reads a CommonMark AST" do
    state :committed

    scope "`scripts/check-rfd-structure.py`, `scripts/check-rfd-numbers.py`,
`scripts/requirements.txt`, `.pre-commit-config.yaml`,
`.github/workflows/checks.yml`"

    attest_in :none

    decision ~S"""
    `scripts/check-rfd-structure.py` parses each `README.md` and `DETAILS.md`
    into a CommonMark AST and checks the document against that tree. It
    joins the inline text of a paragraph before it matches, so a wrapped
    citation is one citation. It found all 37.

    Each rule ran against all 116 RFDs before it became a rule. A rule that
    needed an exception did not ship. The gate reads both its state list and
    its README line limit out of RFD 1000, so document and gate cannot drift
    apart. It takes one dependency, `markdown-it-py`, pinned. The number
    gate keeps numbering only, and its weaker citation scan moved here.
    """

    problem ~S"""
    This repository held 116 RFDs and one gate. That gate checked numbers.
    Nothing checked the shape of a document, so the shape stayed an
    agreement each writer kept from memory.

    A measurement over all 116 found nine kinds of defect. The largest was
    37 citations still in the old decimal form. The number gate looked for
    those and reported 3. An RFD wraps its prose at about 72 columns, so a
    citation splits across a line break, and a scan of the bytes cannot see
    it. That gate measured the file. The rule is about the sentence.
    """

    related ~S"""
    RFD 1000 gives the conventions this gate measures. RFD 1063 moves the
    prose rules to a plugin, and this gate checks structure only.

    See `DETAILS.md` for each rule, its count, the ungated conventions, the
    line limit and the two things it turned up, the defects repaired, and
    the negative controls.
    """

    details_title "The RFD structure gate reads a CommonMark AST"

    details "How the rules were chosen", ~S"""
    Every candidate rule ran against all 116 RFDs before it became a check.
    A rule that held with no exception shipped. A rule that needed an
    exception list did not, and appears under "Measured and not gated"
    below, with its count, because an omitted check reads exactly like a
    passing one.

    The survey script parsed each `README.md` and `DETAILS.md` with
    `markdown-it-py` and counted heading sequences, preamble fields, states,
    citations, and sibling files. It is not kept, because
    `check-rfd-structure.py` now asserts what it measured.
    """

    details "The rules, and what each measured", ~S"""
    | rule | held before the gate |
    | ---- | -------------------- |
    | One level-1 heading, and it opens the document | 116 of 116 |
    | Title reads `RFD <num>: <title>`, number equals the directory | 116 of 116 |
    | A metadata paragraph sits under the title | 116 of 116 |
    | Its fields are State, then Feature, then Scope | 116 of 116 |
    | State is a value RFD 1000 lists | 115 of 116 |
    | Problem, Decision, References and Related keep that order | 116 of 116 |
    | A `## Decision` section is present | 114 of 116 |
    | Every citation resolves to a directory or an ALIASES.md row | 116 of 116 |
    | No citation uses the old decimal form | 84 of 116 |
    | A README names its `DETAILS.md` | 87 of 89 |
    | `DETAILS.md` reads `RFD <num> details: <title>` | 94 of 95 |
    | A README is 40 lines or fewer | 108 of 116 |

    Two of these need their exception stated, because the number above is
    not 116 and the rule still shipped.

    **A `## Decision` section.** The two without it are RFD 1074 and
    RFD 1078. Both carry `State: moved`, which means another repository now
    develops the RFD, and a moved RFD states only where it went. The gate
    requires a Decision unless the state is `moved`, and that holds at 116
    of 116.

    **A retracted decision renames its own heading.** RFD 1067 heads its
    section "Decision, as published and now retracted". The gate matches a
    heading that starts with `Decision` and a comma, so a retraction in
    place does not have to hide behind the original title.
    """

    details "Measured and not gated", ~S"""
    **A `## Problem` section.** 111 of 116. The five without one are
    RFD 1000, RFD 1012, RFD 1015, RFD 1074 and RFD 1078. Two are abandoned,
    two are moved, and RFD 1000 is the conventions document itself. The
    carve-outs would outnumber the signal, so the gate checks the position
    of Problem and not its presence.

    **A `## Related` section.** 111 of 116. RFD 1020, RFD 1021, RFD 1022 and
    RFD 1023 end at their Decision, and RFD 1074 has no section at all. The
    four look like omissions rather than a choice, and adding a section to
    somebody else's RFD is an edit this work did not make.
    """

    details "The line limit, and the two things it turned up", ~S"""
    RFD 1000 stated "under 40 lines" and 8 of 116 READMEs exceeded it, at 41,
    43, 46, 82, 93, 131, 152 and 179 lines. Five were long because they
    carried a retraction in place, which `CLAUDE.md` requires, and that read
    as a conflict between two house rules.

    It was not one. A retraction stays next to what it retracts, and after a
    move the thing it retracts is the detail, which lives in `DETAILS.md`.
    So the retraction goes there too and the rule is unbroken. All eight
    READMEs were split on that reading, and no retraction was deleted.

    Splitting them turned up the second thing. With the eight fixed, **12
    READMEs sat at exactly 40 lines**. Twelve files landing on one number is
    not chance, so the bound the corpus keeps is inclusive and RFD 1000's
    "under 40" was off by one. The document was corrected to "40 lines or
    fewer" and the gate reads the number from that sentence.

    Three of the eight needed real compression rather than a move: RFD 1121,
    RFD 1122 and RFD 1123 state a long decision, and their READMEs went from
    131, 152 and 182 lines to 39 each. Nothing was dropped. Every removed
    section either moved into `DETAILS.md` or was already there in fuller
    form, which is why three of them could go without a replacement.
    """

    details "The defects the measurement found, and the repairs", ~S"""
    | defect | count | repair |
    | ------ | ----- | ------ |
    | Citations in the old decimal form | 37 in 32 files | Rewritten from the ALIASES.md map. The substitution keeps the same four characters, so every line wrap is unchanged |
    | `State: pre-discussion` | 1, RFD 1064 | Corrected to `prediscussion` |
    | A state RFD 1000 does not list | 2, RFD 1074 and RFD 1078 | `moved` added to RFD 1000, because the use predates the list |
    | A `DETAILS.md` no README named | 2, RFD 1118 and RFD 1123 | A pointer line added before Related, where the other 87 put it |
    | A `DETAILS.md` with a title of its own | 1, RFD 1000 | Retitled `RFD 1000 details: numbering` |
    | READMEs over the line limit | 8 of 116 | Split into `README.md` and `DETAILS.md`, retractions included |
    | RFD 1000's limit was off by one | 1 | Corrected to "40 lines or fewer", which is what 12 READMEs already sit on |
    | A heading written twice on one line | 1, RFD 1122's `DETAILS.md` | `## What exists, and what does not## What exists, and what does not` |
    | An RFD after the migration cannot pass | latent | See below |

    The last one had not fired yet. `check-rfd-numbers.py` required an
    ALIASES.md row for every directory. ALIASES.md maps an old number to a
    new one, and an RFD written after the migration has no old number. This
    RFD is the first such RFD, and it would have failed the gate that
    records how it is numbered. The check now reads the migrated range out
    of the table and applies only inside it.
    """

    details "Why an AST, in a repository that had no dependency", ~S"""
    The gap is measurable rather than theoretical. The byte scan found 3 of
    the 37 unmigrated citations. The other 34 sat across a line break, and
    `RFD` on one line with `0019` on the next is two unrelated tokens to a
    regular expression and one citation to a reader.

    Widening the expression to allow a newline would repair that one case.
    It would not repair the next one, because the class of defect is reading
    markup as text. The AST is where the distinction lives, and every later
    rule here reuses it: the metadata fields come from the strong-emphasis
    tokens rather than from counting asterisks, and the section spine comes
    from heading tokens rather than from lines that start with a hash.

    `markdown-it-py` is pinned in `scripts/requirements.txt`. A parser change
    would move what the gate sees, and a gate that changes verdict without a
    diff is not a gate.
    """

    details "The negative controls", ~S"""
    `python scripts/check-rfd-structure.py --self-test` builds a small tree
    for each case and asserts the verdict. One case is a clean tree that
    must pass. Fifteen are known-bad trees that must fail:

        title number disagrees with the directory
        the title is not the first block
        a second level-1 heading
        no metadata paragraph
        a state RFD 1000 does not list
        Scope written before Feature
        an unknown metadata field
        no Decision section
        Decision written before Problem
        a decimal citation split across a line break
        a citation that resolves nowhere
        a DETAILS.md the README never names
        a DETAILS.md titled for another RFD
        a README past the line limit RFD 1000 gives

    `check-rfd-numbers.py` carries seven of its own, including the two that
    reject the withdrawn hex form: a hex directory name must fail, and so
    must a hex heading over a decimal directory.

    Both self-tests run before the gate itself in
    `.github/workflows/checks.yml`, so each proves it can reject before it
    judges the repository.
    """

    details "What the decimal renumbering withdrew", ~S"""
    Every count above was measured against the corpus while RFD numbers were
    hexadecimal and `ALIASES.md` existed. RFD 1000 renumbered the corpus to
    decimal and deleted that table. The measurements stay as measured. Two of
    the rules they produced do not.

    The row reading "Every citation resolves to a directory or an ALIASES.md
    row" now reads "to a serial `SERIALS.usda` lists", live or deleted. This
    gate borrows `check-rfd-serials.py`'s reader rather than parsing the
    register a second way, so the two cannot disagree about which numbers
    exist. That is the arrangement the state list and the line limit already
    use, one file further along.

    An earlier draft of this paragraph said the gate parses the deleted numbers
    out of RFD 1070's prose. It did, for one commit, and the register replaced
    it. The paragraph is corrected rather than deleted because a document that
    states a rule the code does not implement is the failure this whole RFD was
    written against, and it happened here.

    The row reading "No citation uses the old decimal form" now covers two
    withdrawn forms. A number beginning with 0 is the first. A serial carrying
    a letter is the second, and 131 RFDs wore it.
    """

    drafted_by :ai
  end
end
