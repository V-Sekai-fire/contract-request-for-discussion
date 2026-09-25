# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1114. `mix rfd.render` renders rfd/1114-app-chrome-layout-invariants/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1114 do
  use RFD.DSL

  rfd 1114, "App chrome layout invariants" do
    state :committed

    scope "`App.jsx`, `App.css`, `TaskProgressBar.{jsx,css}`,
`src/pages/Appearance*`, `BottomDisplayMenu.jsx`"

    attest_in :none

    decision ~S"""
    The task-progress bar stays in document flow, after
    `.scene-controls-row`, never `position: fixed` over the header. The
    right rail (`.weftspun-sidebar`) reads its top offset from a measured
    `--app-content-top`, set on `:root`, never redefined on `.app`. A
    fixed pixel top, or a chrome-calc top without that measured
    variable, both regress this.

    Both collapsed rails (`.sidebar`, `.weftspun-sidebar`) share one set
    of `--collapsed-rail-*` tokens for width, icon size, gap, and
    padding, defined once on `.app`. Neither rail takes a per-side
    override.

    Three z-index layers stack in one order: side panels at 998
    (`--z-side-panel`), the header at 1001, the scene controls row at 1002. A side panel
    overlapping the header gets a `top` fix, never a
    z-index raise past 998.

    See `DETAILS.md` for the full token table, the forbidden-change
    list, and the visual-check steps each rule's own checklist named.
    """

    problem ~S"""
    The header, the task-progress bar, and the two side rails share one
    coordinate space. Three regressions kept recurring: a fixed task bar
    drifting over the header, an asymmetric collapsed-rail icon column,
    and a side panel raised above the header in z-index instead of
    repositioned.
    """

    related ~S"""
    RFD 1001 gives the shell these invariants live inside.
    """

    details_title "App chrome layout invariants"

    details_preamble ~S"""
    Sourced from `app-chrome-layout-protected.mdc`,
    `collapsed-rail-icons.mdc`, and `sidebar-z-index.mdc`
    (user-confirmed good state, 2026-06-18).
    """

    details "Tokens", ~S"""
    | Token                                          | Purpose                                                          | Owner                                 |
    | ---------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------- |
    | `--app-content-top`                            | Measured top offset, read by the right rail                      | `:root`, from `App.jsx`; never `.app` |
    | `--collapsed-rail-width`                       | Collapsed rail width, both sides                                 | `.app`                                |
    | `--collapsed-rail-icon-width` / `-icon-height` | Icon button size, matches the scene-controls hamburgers at 40x40 | `.app`                                |
    | `--collapsed-rail-icon-gap`                    | Vertical gap between icons                                       | `.app`                                |
    | `--collapsed-rail-icon-padding`                | Icon column padding                                              | `.app`                                |
    | `--z-side-panel`                               | Side panel z-index, 998                                          | `.app`                                |
    | `--z-app-header`                               | Header z-index, 1001                                             | `.app`                                |
    | `--z-scene-controls`                           | Scene controls row z-index, 1002                                 | `.app`                                |
    """

    details "Shared selectors, styled together", ~S"""
    Containers: `.collapsed-sidebar-icons`, `.collapsed-weftspun-icons`.
    Buttons: `.sidebar-icon`, `.weftspun-sidebar-icon`. Collapsed width:
    `.sidebar.collapsed`, `.weftspun-sidebar.collapsed`.

    In-panel hamburgers (`.hamburger-menu`, `.weftspun-sticky-hamburger`)
    set `display: none` when collapsed. The scene-controls row hamburgers
    stay the active controls in that state.
    """

    details "Forbidden without an explicit user request", ~S"""
    - A fixed task bar with a hardcoded `top` (for example `52px`), or a
      z-index above the header band.
    - The right rail's `top` set from `--app-chrome-top-height` alone,
      without `--app-content-top`.
    - An asymmetric `padding-top` on one collapsed rail only.
    - Removing the `TaskAdvancedOptions` import from `TaskManager.jsx`.
    - A side panel z-index raised past 998 to fix an overlap; fix `top`
      instead.
    """

    details "Protected files", ~S"""
    `App.jsx`, `App.css`, `TaskProgressBar.jsx`, `TaskProgressBar.css`,
    `TaskManager.jsx` (the `TaskAdvancedOptions` import),
    `src/pages/Appearance*.{css,jsx}`, `BottomDisplayMenu.jsx`.
    """

    details "Visual check, before merging a layout touch", ~S"""
    Both rails collapsed: icon rows align, row for row, left to right.
    A running task: the progress bar sits below the scene-controls row,
    the header stays clickable, and both rails stay aligned.
    """

    drafted_by :ai
  end
end
