# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2256. `mix rfd.render` renders rfd/2256-webtransport-inside-a-sandbox-guest/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2256 do
  use RFD.DSL

  rfd 2256, "WebTransport inside a sandbox guest" do
    state :ideation

    feature "A godot-sandbox guest carries bulk game traffic over QUIC,
HTTP/3 and WebTransport at binary-translated speed, and the first
channel it carries mints tokens from a key the host never sees"

    scope "a godot-sandbox guest ELF running the QUIC stack, the zone
server and clients that host it, and a token-minting channel as
its first user; nothing is built yet"

    decision ~S"""
    QUIC, HTTP/3 and WebTransport run inside a RISC-V guest ELF that
    libriscv binary-translates to near native speed: picoquic with
    h3zero, TLS 1.3 through picotls on mbedTLS. The host relays UDP
    through `PacketPeerUDP` and ticks timers without seeing
    plaintext. The first channel is a signer on a zone server whose
    app key lives only in guest memory; it checks a ReBAC tuple and
    returns a one-hour installation token, never the key.
    """

    problem ~S"""
    A key on the desk, or a helper that hands out a token, is open to
    every script there. Only a separate peer keeps it out of reach.
    """

    related ~S"""
    - RFD 2255 (SSH tunnel to Bao), the path the signer peer's
      identity can use to reach Bao.
    - RFD 2060 (org-scoped app token), the token this mints.
    - RFD 2200 (ReBAC agent roles as tuples), the authorization.
    """

    drafted_by :ai

    details_title "a token-minting guest over WebTransport"

    details "The exchange", ~S"""
    1. The signer guest starts, logs in to Bao with its own cert
       identity over mTLS terminated inside the guest, and reads the
       app key into guest memory.
    2. An agent's guest opens a WebTransport session to the zone
       server on UDP 7443 and sends a mint request naming itself.
    3. The signer checks `agent:<cn>#mint@app:<app>` in the
       relationship store and refuses without it.
    4. It signs a JWT, exchanges it for an installation token over
       TLS inside the guest, and returns the token and its expiry.
    """

    details "What is not settled", ~S"""
    - **Throughput.** Bulk game traffic needs the binary-translated
      guest to keep up with a native QUIC stack. Nothing is measured
      yet; the comparison is the same stack built native against the
      translated guest, same payload, same link.
    - **Per-call instruction budget.** Translation shortens a TLS 1.3
      handshake but does not remove the sandbox's per-call limit, so
      the budget for this guest is set from a measured handshake.
    - **Transport.** WebTransport is the proposal; ENet through the
      existing ENet sandbox is the fallback if the translated QUIC
      guest cannot carry the traffic.
    - **Licences.** picoquic, picotls and mbedTLS are MIT or
      Apache-2.0. libriscv and godot-sandbox are BSD-3-Clause, so
      an MIT-or-Apache-only rule needs an exception for the host.
    - **Which peer.** A zone server the operator runs, on owned
      hardware or the existing hosting; the choice decides who can
      read that peer's memory.
    """
  end
end
