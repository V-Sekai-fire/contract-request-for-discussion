# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1145. `mix rfd.render` renders rfd/1145-stylized-to-omnigen2/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1145 do
  use RFD.DSL

  rfd 1145, "The stylized-to-OmniGen2 loop" do
    state :published

    feature "loop 3 of the four-loop plan"

    scope "`fourloops-plan.usda`"

    attest_in :none

    decision ~S"""
    Run it, and treat everything it touches as evaluation only.

    **The hazard is the holdout.** The COCO-OOD stylized sets are
    `val2017` restyled, so they are held out twice over: derived from the
    blinded holdout, and generated. CLAUDE.md states the rule this loop is
    most likely to break — anything derived from `val2017` inherits its
    status, and a set generated from a held-out photo carries that photo's
    content wherever it goes.

    So loop 3 produces no training data, whatever it produces. A stylized
    corpus that reaches a training run has taken the holdout with it, and
    nothing downstream would report that it had.
    """

    problem ~S"""
    Loop 3 is loop 2 with a style transfer in front of it: CycleGAN
    proposes a restyled image, OmniGen2 edits it, EditScore scores the
    result and OmniGen2 repairs. The artifact is an edited png at the size M, the same as loop 2.

    What makes it a separate loop rather than a variant is where its input
    comes from, and that is a licensing question before it is a technical
    one.
    """

    related ~S"""
    RFD 1143, RFD 1144 and RFD 1146 are the other three loops. RFD 1122 is
    the goal that the four serve.
    """

    drafted_by :ai
  end
end
