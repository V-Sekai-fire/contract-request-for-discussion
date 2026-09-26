# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2242. Abandoned; the live ggml-consumer shape is RFD 2230.
defmodule RFD2242 do
  use RFD.DSL

  rfd 2242, "ggml consumers as native Godot modules stacked on modules/ggml" do
    state :abandoned

    feature "retracted"

    scope "retracted"

    decision ~S"""
    Retracted 2026-09-26. The live shape is godot-sandbox to ggml-rd to
    compute-rd, the sandboxed-adapter design of RFD 2230, not one native
    module per consumer. See RFD 2230.
    """

    drafted_by :ai
  end
end
