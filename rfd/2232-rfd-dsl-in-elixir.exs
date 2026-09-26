# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2232. `mix rfd.render` renders rfd/2232-rfd-dsl-in-elixir/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2232 do
  use RFD.DSL

  rfd 2232, "RFD authoring as an Elixir DSL" do
    state :discussion

    feature "one `rfd/NNNN-slug.exs` per RFD and one `SERIALS*.exs` per site, compiled by `rfd_dsl`; the Markdown and the `.usda` registers are renderings of them and are not tracked"

    scope "the Mix project at the repository root, every `rfd/*.exs`, `SERIALS.exs` and `SERIALS-vsekai-fabric.exs`, the site and the MCP endpoint it serves"

    decision ~S"""
    An RFD is an Elixir module that uses `RFD.DSL`: one `rfd` block with
    `state`, `feature`, `scope`, `flight_level`, `decision`, `problem`,
    `references`, `related`, `details` sections and `drafted_by`. The block
    builds an `RFD.Doc` and validates it against RFD 1000 while the file
    compiles, so a state outside the list, a missing Decision or a README over
    40 lines is a compile error that names the rule. A site's serial register
    is a module that uses `RFD.Register`: `allocated`, `unused` and `deleted`
    blocks of `serial`, `never_written` and `retired` rows. `mix rfd.render`
    writes README.md, DETAILS.md and `SERIALS*.usda`, the shape the gates and
    `pen-66606.usda` read, and those files are ignored by git. The same corpus
    is a site and a public MCP endpoint on Fly. `DETAILS.md` carries the rest.
    """

    problem ~S"""
    The shape was enforced after the fact by Python gates reading Markdown,
    and 143 problems accumulated before one pass fixed them. The register was
    a hand-edited layer nothing compiled: it carried one serial on two
    directories, one serial allocated and deleted at once, and two slugs that
    no longer matched their directories. The taskweft domains beside many RFDs
    are already Elixir, so the authoring form that can refuse a malformed
    document before it is written is the language the repository already runs.
    """

    references ~S"""
    - RFD 1000, the shape
    - RFD 2177, the flight_level tag on the register
    """

    related ~S"""
    RFD 1000 (the README limit and the spine), RFD 2177 (the register carries `flight_level`, so the DSL writes it to the register row, not the README), RFD 2026 (commit style the rendered files ride on).
    """

    details_title "RFD authoring as an Elixir DSL"

    details "Layout", ~S"""
    One file per RFD, `rfd/NNNN-slug.exs`, rendered into `rfd/NNNN-slug/`.
    A directory exists in git only when it carries apparatus beside the
    document (a USD layer, a skill, a script); README.md, DETAILS.md and
    `index.md` under `rfd/` are build artifacts and `.gitignore` names them.
    The registers are `SERIALS.exs` (site 1, frozen) and
    `SERIALS-vsekai-fabric.exs` (site 2, where new serials come from), rendered
    to the `.usda` beside them. A new RFD is a new `.exs` and a new `serial`
    line in the site's `allocated` block; `mix rfd.serials` refuses a source
    with no row, a row with no source, a slug that disagrees with the file
    name, and a deleted serial that has a source.
    """

    details "What the render is checked against", ~S"""
    `mix test` at the root runs the positive cases and the negative
    controls: an unknown state, a missing Decision, a 40-line overflow, a
    serial listed twice, a serial from another site, a retired row naming no
    serial, a renumbering and a revived serial are each refused. The rendered
    tree then passes `check-rfd-structure.py`, `check-rfd-serials.py`,
    `check_tropes.py` and `check_rfd_canary.py` unchanged, which is the
    compatibility claim: the DSL emits what the existing pipeline consumes.
    CI and the prek hooks render before any gate reads the tree, and the
    diff-based gates scope themselves by the changed `.exs` sources.
    """

    details "What the conversion found", ~S"""
    Importing 306 RFDs lost no line of prose (`mix rfd.import` refuses a
    lossy import). Importing the two registers refused four rows: serial
    2143 named both `fdb-backup-fans-out-to-r2` on main and
    `close-out-gates-red-green-scout` from a merged branch, so the second
    took the next unused serial, 2233; serial 2169 was allocated and deleted
    at once; 2184 and 2186 carried slugs their directories had left behind;
    and 2232 had been appended into the deleted scope. Tropes are warnings at
    compile time, not errors, because `check_tropes.py` holds density where
    it is rather than forbidding a tell.
    """

    details "The site and the MCP endpoint", ~S"""
    `RFD.Corpus` loads every source once; `RFDWeb.Router` serves the register,
    each RFD, the flight levels, the logbook, the serial pages and the
    agreements as plain HTML, and forwards `/mcp` to `ExMCP.HttpPlug` over
    `RFD.MCP.Server`, whose tools (`list_rfds`, `get_rfd`, `search_rfds`,
    `get_register`, `list_logbook`, `get_logbook_entry`, `get_agreements`) are
    public and read-only. `mix rfd.pack` writes `priv/corpus.bin` so the Fly
    release boots without compiling; `Containerfile`, `fly.toml` and the
    Deploy workflow carry it, and Quarto with the GitHub Pages site is gone.
    """

    details "What the DSL does not do", ~S"""
    It does not read the register from the RFD sources: a serial is a fact the
    register records once, and a deleted serial has no source to derive it
    from. It does not write: the endpoint answers, and a change is a pull
    request.
    """

    drafted_by :ai
  end
end
