# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2172. `mix rfd.render` renders rfd/2172-tenseless-continuous-present-voice/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2172 do
  use RFD.DSL

  rfd 2172, "Prose speaks in the tenseless continuous present" do
    front_matter ~S"""
    ---
    name: rfd-2172-tenseless-continuous-present-voice
    description: When writing prose (code comment, RFD, changelog, README, PR description) in this workspace, state what is currently true of the system. Rule out past-tense edit narration, future or imperative planning, and aging temporal qualifiers.
    tools: Read, Write, Edit
    ---
    """

    state :committed

    feature "prose voice for code comments, RFDs, and changelog entries"

    scope "every `.md`, `.qmd`, and code-comment file in the workspace"

    decision ~S"""
    Prose in this workspace states what is currently true of the system; every sentence describes behaviour a reader can check against the code in front of them.
    """

    problem ~S"""
    Comments and prose drift out of sync with code as the system changes. A comment written as history ("added a cache", "we removed the old path") or as a plan ("will solve this", "TODO: wire X") describes a moment that has passed or has not yet arrived; a reader cannot check it against the code in front of them. RFD 2025 (sinew voice ADR, migrated) settled the rule; this RFD promotes it to a workspace convention.
    """

    section "Three habits ruled out", ~S"""
    - Past-tense edit narration ("removed the legacy path"). Git holds history.
    - Future or imperative planning ("will add", "TODO"). RFDs and issues hold plans.
    - Aging temporal qualifiers ("now", "currently", "previously"). A qualifier that goes stale on the next edit signals the sentence should have described a truth.

    Unfinished areas read as present gaps ("the parser handles no Unicode escapes yet"), not as tasks. A stale sentence signals a real divergence from the code, which makes review catch it.
    """

    related ~S"""
    Promotes: RFD 2025 (sinew voice ADR).
    Companion to RFD 1125 (two prose gates) and CLAUDE.md's trope-density check.
    """

    drafted_by :ai
  end
end
