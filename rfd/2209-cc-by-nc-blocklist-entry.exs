# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2209. `mix rfd.render` renders rfd/2209-cc-by-nc-blocklist-entry/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2209 do
  use RFD.DSL

  rfd 2209, "CC-BY-NC as a blocklist entry" do
    compact_head true

    state :discussion

    feature "add `CC-BY-NC` (all versions) to CLAUDE.md's blocklist
alongside `CC-BY-SA`, and gate build scripts to drop CC-BY-NC rows
before shipping any derived corpus"

    scope "every corpus builder that reads a mixed-licence source
document; today's concrete case is
`scripts/build_starforged_hf.py` and `build_starforged_sqlite.py`
against the dataforged repo"

    decision ~S"""
    Add a row to CLAUDE.md's "Blocklists" table:

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    Concrete case that produced this RFD: **dataforged**, the
    community JSON rendering of the Starforged and Ironsworn SRDs at
    `github.com/rsek/dataforged`, carries a mixed licence:
    """

    related ~S"""
    - CLAUDE.md's existing `CC-BY-SA` row, same shape, same argument.
    - RFD 2205 (Taskweft in Bao), the Starforged play surface whose
      corpus is the concrete case.
    - Codebase: `2-contract/manuals-weftspun/scripts/build_starforged_hf.py`
      and `build_starforged_sqlite.py`, the reference filter
      implementations.
    - Codebase: `2-contract/manuals-weftspun/scripts/check_starforged_hf.py`
     , the downstream CI assertion.
    """

    details_title "CC-BY-NC as a blocklist entry"

    details "The BLOCKLIST.md section to add", ~S"""
    Below the `CC-BY-SA` section, add:

        ### CC-BY-NC (all versions)

        A non-commercial restriction on a row propagates into any
        corpus, dataset, or artifact that ships the row. The
        workspace's deployments (VRChat, service demos, HF datasets,
        trained models) are commercial in the sense the licence
        excludes, sales, ad-supported distribution, and paid access
        are all on the table for shipped work, and a licence that
        reserves them defeats the downstream question before it is
        asked.

        Same shape as CC-BY-SA's row. Different clause (non-commercial
        vs. share-alike); the downstream cost of ignoring it is the
        same.

        **Concrete case (2026-09-05):** dataforged
        (`github.com/rsek/dataforged`) carries a mixed licence.
        `dist/starforged/*.json` is CC-BY-4.0 and ships as
        `chibifire/starforged` on HuggingFace. The `ironsworn/`
        subtree and raster illustrations are CC-BY-NC-4.0 and are
        filtered out by `scripts/build_starforged_hf.py` before the
        parquet write. `scripts/check_starforged_hf.py` asserts every
        surviving row is CC-BY-4.0 as a rule-3 named-not-silent gate.

        **What is not banned.** Reading CC-BY-NC content for
        inspection, citing it in an RFD, or naming it as a source is
        fine. Shipping its content in a derived corpus is the case
        this row covers.
    """

    details "Filter implementation shape", ~S"""
    Every builder that ingests a mixed-licence source carries the
    same three-step shape:

    1. Read the source row.
    2. Consult the row's licence field (dataforged tags each entry;
       other sources may need per-source lookup logic).
    3. If `licence in {"CC-BY-NC-4.0", "CC-BY-NC-3.0",
       "CC-BY-NC-SA-*", "CC-BY-NC-ND-*"}`, drop the row and
       increment a counter.

    At the end of the build, print the drop count and a per-licence
    histogram of dropped rows. A silent skip reads as a pass; rule 3
    says name the count. The reference implementation is in
    `scripts/build_starforged_hf.py` from the current session.
    """

    details "Verification", ~S"""
    - **Positive:** `check_starforged_hf.py` reads the shipped
      parquet shards and asserts `every row's licence == CC-BY-4.0`.
    - **Negative control** (rule 2): the checker's `--self-test`
      mutates one row's licence field to `CC-BY-NC-4.0` in memory
      and asserts the checker fails on that row.
    - **Builder self-test:** `build_starforged_hf.py --self-test`
      runs against a small hand-built fixture with a planted
      CC-BY-NC row and asserts the row is dropped, the drop count is
      1, and the output does not contain the row's id.
    """

    details "Related retractions", ~S"""
    None. The blocklist row is additive; no earlier decision is
    withdrawn. The corresponding CC-BY-SA row on the blocklist is not
    touched.
    """

    details "From the README, moved here on 2026-09-07", ""

    details "Decision", ~S"""
    Add a row to CLAUDE.md's "Blocklists" table:

        | **CC-BY-NC (all versions)** | non-commercial restriction propagates into anything derived from the row, same downstream-risk shape as CC-BY-SA, see below |

    with a corresponding section in `BLOCKLIST.md` argued below. The
    row is enforced two places:

    1. **Build-script filter.** Any script that ingests a mixed-licence
       source reads each row's licence field and drops CC-BY-NC rows
       before the parquet or SQLite write. Reports the drop count as a
       rule-3 named-not-silent gate.
    2. **CI on manuals-weftspun.** `scripts/check_starforged_hf.py`
       asserts `every row's licence == CC-BY-4.0` (or another
       commercial-clean licence the workspace already accepts). A
       CC-BY-NC row surviving the filter fails CI.

    The rule does NOT ban *reading* CC-BY-NC content locally for
    inspection. It bans CC-BY-NC rows from shipping in a derived
    corpus, a training dataset, a demo fixture, or any artifact this
    workspace publishes.
    """

    details "Problem", ~S"""
    Concrete case that produced this RFD: **dataforged**, the
    community JSON rendering of the Starforged and Ironsworn SRDs at
    `github.com/rsek/dataforged`, carries a mixed licence:

    - `dist/starforged/*.json`, CC-BY-4.0. Ships.
    - `ironsworn/` subtree, CC-BY-NC-4.0. Filtered out.
    - Raster illustrations, CC-BY-NC-4.0. Filtered out.

    Without the filter, `chibifire/starforged` on HuggingFace would
    have shipped CC-BY-NC rows mixed with CC-BY-4.0 rows under a
    single licence declaration. That is a licence-provenance failure
    for downstream consumers who take the workspace at its word that
    `chibifire/starforged` is CC-BY-4.0. The filter closes it. The
    row on CLAUDE.md's blocklist ensures the *next* mixed-licence
    source (dataforged is not going to be the last) inherits the same
    handling by default rather than by anyone remembering.

    The failure mode is the same as CC-BY-SA's, a share-alike or
    non-commercial restriction that propagates into anything derived
    from the row. Different clause, same downstream shape. The CC-BY-SA
    row already on the blocklist is the argument this row mirrors.
    """

    details "Non-goals", ~S"""
    Not a rule against every restrictive licence, CC0, MIT, Apache,
    CC-BY-4.0, and the other permissive licences the workspace
    already accepts continue to. Not a rule against downloading
    CC-BY-NC content for personal inspection (an operator reading the
    Ironsworn PDF is fine; a corpus builder ingesting its text is not).
    Not a rule against forking or citing CC-BY-NC works, attribution
    of a source is different from shipping its content.
    """

    details "Related", ~S"""
    - CLAUDE.md's existing `CC-BY-SA` row, same shape, same argument.
    - RFD 2205 (Taskweft in Bao), the Starforged play surface whose
      corpus is the concrete case.
    - Codebase: `2-contract/manuals-weftspun/scripts/build_starforged_hf.py`
      and `build_starforged_sqlite.py`, the reference filter
      implementations.
    - Codebase: `2-contract/manuals-weftspun/scripts/check_starforged_hf.py`
     , the downstream CI assertion.
    """

    drafted_by :ai
  end
end
