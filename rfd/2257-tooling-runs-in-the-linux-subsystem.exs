# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2257. `mix rfd.render` renders rfd/2257-tooling-runs-in-the-linux-subsystem/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2257 do
  use RFD.DSL

  rfd 2257, "workspace tooling runs in the Linux subsystem" do
    state :committed

    feature "Every workspace tool on a desk runs inside the host's Linux
subsystem, with the host's network mirrored in, so one
toolchain and one credential store serve the whole session"

    scope "the desks' host operating system, the subsystem's `.wslconfig`,
and the pixi environments the gates run in"

    decision ~S"""
    The desk's host operating system is blocklisted as a place to run
    workspace tooling: `repo`, `pixi`, the `bao` and 1Password CLIs,
    the gates, builds and runs all run in the Linux subsystem. The
    subsystem uses mirrored networking (`networkingMode=mirrored` in
    `%UserProfile%\.wslconfig`), so it shares the host's IPv6 route.
    A release artifact built for the host is still tested on the
    host; this rule governs where tools run, not what ships.
    """

    problem ~S"""
    A tool installed on both sides keeps two copies of its state: the
    password manager answered on one side and not the other, and the
    Bao CLI existed on only one. Under NAT the subsystem had no IPv6,
    so it could not reach Bao's public tunnel address at all.
    """

    related ~S"""
    - RFD 2255 (SSH tunnel to Bao), the path IPv6 opened.
    - RFD 2016 (checking sccache), whose cross-shell driver this
      rule changes.
    """

    drafted_by :ai

    details_title "workspace tooling runs in the Linux subsystem"

    details "What is measured", ~S"""
    Under NAT, `ip -6 route` held only the link-local route and an
    IPv6 fetch returned nothing, while the host reached the same
    address. After `networkingMode=mirrored` and a restart, the
    subsystem fetched over IPv6 (HTTP 200) and opened the Bao tunnel
    on its public IPv6 address.
    """

    details "The toolchain", ~S"""
    Elixir 1.20.4 on Erlang/OTP 29.1.1 comes from pixi (`pixi global
    install --environment elixir`), the same pair CI pins, and
    `~/.pixi/bin` sits ahead of the host PATH the subsystem appends.
    The request-for-discussion pixi workspace declares `linux-64`.
    """
  end
end
