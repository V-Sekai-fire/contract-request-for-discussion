# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2261. `mix rfd.render` renders rfd/2261-mbedtls-is-the-tls-library/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2261 do
  use RFD.DSL

  rfd 2261, "mbedTLS is the TLS library" do
    state :committed

    feature "New TLS, mutual-TLS and signing code, sandbox guests included,\nbuilds on mbedTLS"

    scope "code this workspace writes that opens TLS, presents a client
certificate or signs a token"

    decision ~S"""
    mbedTLS (Apache-2.0) is the TLS and crypto library for new code:
    the same library Godot vendors, so an engine build and a guest
    ELF share one implementation. It covers mutual TLS with an agent
    certificate and the RS256 signing an app-token JWT needs.
    """

    problem ~S"""
    Each new component chose its own TLS stack, and a guest ELF that
    must reach Bao needs client certificates the engine's HTTP client
    cannot present.
    """

    related ~S"""
    - RFD 2256 (WebTransport inside a sandbox guest), whose QUIC stack
      runs TLS 1.3 through picotls on mbedTLS.
    """

    drafted_by :ai

    details_title "mbedTLS is the TLS library"
  end
end
