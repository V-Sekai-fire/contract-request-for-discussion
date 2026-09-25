# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2101. `mix rfd.render` renders rfd/2101-zstd-delta-on-the-wire/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2101 do
  use RFD.DSL

  rfd 2101, "zstd delta on the wire" do
    state :discussion

    scope "the apparatus in this directory"

    decision ~S"""
    None recorded. The serial was allocated and the apparatus (`wire.c`) was written; the document
    was not. The serial stays allocated, as RFD 1000 says a serial never moves once issued.
    """

    problem ~S"""
    A directory with code and no README reads as a document that was deleted rather than one that
    was never written. This page names which it is.
    """

    drafted_by :ai
  end
end
