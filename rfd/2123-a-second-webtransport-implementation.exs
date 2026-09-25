# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2123. `mix rfd.render` renders rfd/2123-a-second-webtransport-implementation/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2123 do
  use RFD.DSL

  rfd 2123, "A second webtransport implementation" do
    state :moved

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    One disagreement about the contract, and three integration defects
    found while building. The distinction matters, because only the first
    is the thing a second implementation exists to produce: it is a claim
    the fabric makes about its own wire, contradicted by two stacks that
    share no code. The other three are properties of the libraries this
    pair happens to use, and a third implementation on a fourth stack
    would not have found them.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "A second webtransport implementation"

    details "What the second implementation found", ~S"""
    One disagreement about the contract, and three integration defects found while building. The
    distinction matters, because only the first is the thing a second implementation exists to
    produce: it is a claim the fabric makes about its own wire, contradicted by two stacks that
    share
    no code. The other three are properties of the libraries this pair happens to use, and a third
    implementation on a fourth stack would not have found them.

    All measured on 2026-08-17, macOS arm64, over a loopback session. Each is recorded in the
    `OPEN_GAPS.md` of the repository that found it.

    ### A 64-entity slice does not fit in one datagram

    `transport-fanout/src/fanout.h:39` caps a subscriber's slice and states the reason: "Cap one
    subscriber's slice so a single write stays inside a datagram-sized batch. 64 entities \* 100
    bytes
    = 6400 bytes, comfortably inside one message."

    Two implementations sharing no code disagree with that comment and agree with each other, one
    fresh connection per size:

    | stack                   | largest datagram | whole records | failure above the limit   |
    | ----------------------- | ---------------- | ------------- | ------------------------- |
    | `aioquic` 1.3.0         | 1169 bytes       | 11            | queues the frame and jams |
    | `pywebtransport` 0.20.1 | 1161 bytes       | 11            | refuses at the API        |

    The eight-byte difference is header overhead and both land on 11 records. The cause is
    structural
    rather than a library limit: a DATAGRAM frame has to fit inside one QUIC packet, and `aioquic`
    reports `_max_datagram_size = 1200` against a negotiated `_remote_max_datagram_frame_size =
    65536`,
    so the packet size binds and the frame limit never does. 6400 bytes is five QUIC packets.

    `datasource-queen/src/wt.c:32` sets `WT_MTU_MAX` to 1300, which is 13 records, so the C side's
    configuration contradicts the C side's comment before either Python implementation is
    considered.
    `transport-fanout` has never run and `transport-ingest-c` has no `main`, so nothing had
    exercised
    the claim.

    `transport-ingest-python` splits a slice at 11 records so it runs. What stays open is whether
    `MAX_SLICE_ENTITIES` is wrong, whether slices belong on streams, or whether `fanout_one`'s
    silent
    truncation at 64 was always the real cap.

    ### A library defect: one oversized datagram jams every datagram after it

    `aioquic`'s `_write_datagram_frame` asks the packet builder for room, and when the frame
    cannot
    fit, the caller breaks out of the send loop without popping the queue, so the oversized
    datagram
    stays at the head forever.

    Measured: after one 6400-byte send, three subsequent 100-byte datagrams never arrived and the
    pending queue grew from one entry to three. One bad send does not lose one message, it ends
    that
    session's datagram path.

    `transport-ingest-python` fragments against the connection and refuses anything over the cap,
    so
    it cannot trigger this. Reporting it upstream was considered and dropped: the trigger is an
    application sending a datagram larger than a packet, which RFC 9221 already forbids, so it is
    misuse handling rather than a protocol defect and it is not reachable from peer input. quiche
    exposes `dgram_max_writable_len` and quic-go returns a too-large error carrying the size,
    while
    aioquic documents no size contract and exposes no way to query one, which is why
    `datagram_capacity` reads private attributes.

    This also contaminated a measurement. A binary search over delivery first returned 1050 bytes,
    because one oversized probe jammed the connection and every later size read as lost. Datagrams
    are
    unreliable, so a threshold cannot be probed on one connection at all, which is why the table
    above
    uses a fresh connection per size.

    ### A library limit: pywebtransport rejects EC server keys, and that decided the stack

    `contract-wt/README.md` records the Godot demo server building "a fresh self-signed P-256
    certificate on every run". `pywebtransport` refuses to open a listener with one, failing with
    "failed to parse private key as RSA, ECDSA, or EdDSA". PKCS#8 keys from LibreSSL 3.3.6:

    | key                   | `pywebtransport` 0.20.1 | `aioquic` 1.3.0 |
    | --------------------- | ----------------------- | --------------- |
    | EC prime256v1 (P-256) | rejected                | accepted        |
    | EC secp384r1 (P-384)  | rejected                | accepted        |
    | RSA 2048              | accepted                | accepted        |
    | Ed25519               | untested                | untested        |

    Ed25519 is untested on both because LibreSSL 3.3.6 answers `Unknown algorithm ed25519` and no
    key
    was produced to try.

    Each end's key is its own, so this never stopped the two talking. It stopped the Python pair
    serving a role the Godot side serves today, which is why the pair moved to `aioquic`. A live
    session with a P-256 server key answers CONNECT with `:status 200`.

    ### A configuration defect: a default iceoryx2 subscriber drops the oldest of three sends

    `iceoryx2` defaults a subscriber's buffer to **2** samples with safe overflow on. Three
    records
    published in a burst arrived as two, and the missing one was the oldest, before any reader was
    slow. Both repositories now set the buffer explicitly and keep safe overflow, because RFD 2108
    requires that a lagging reader never stall the writer.

    The drop stays undetectable. `HeaderPublishSubscribe` carries a node id, a publisher id and an
    element count, and no sequence number, so nothing distinguishes a dropped sample from one
    never
    sent. RFD 2108 says a subscriber whose cursor falls out of the ring "receives a resync signal
    rather than a gap"; no such signal exists, and defining one is a wire decision.
    """

    details "The renames", ~S"""
    Two repositories renamed, two created. GitHub redirects the old names.

    | before              | after                      | path                         |
    | ------------------- | -------------------------- | ---------------------------- |
    | `transport-gateway` | `transport-gateway-c`      | `1-transport/gateway-c`      |
    | `transport-ingest`  | `transport-ingest-c`       | `1-transport/ingest-c`       |
    |,                   | `transport-gateway-python` | `1-transport/gateway-python` |
    |,                   | `transport-ingest-python`  | `1-transport/ingest-python`  |

    `check_path_recomposes` in `check_docs.py` requires the directory and its child to rebuild the
    repository name, and all four do. The manifest count moves from 45 to 47.

    Both C repositories carried a description using a word RFD 2111 retired, "hands the result to
    a
    **plane** over iceoryx2", because the READMEs were converted and the GitHub descriptions were
    missed. Both now say interactor.

    `check_docs.py`'s moved-repository check found eight stale references in six files across five
    repositories, each fixed in its own pull request: `transport-fanout`, `transport-gateway-c`,
    `transport-ingest-c`, `interactor-ward`, `entities-gyre` and `datasource-queen`.
    """

    details "Why the language and not the library", ~S"""
    RFD 2111 retires names that say how a thing was built, and `-c` and `-python` are exactly
    that. The
    rule targets directories that collect whatever nobody classified: `service/`, `lean/`,
    `engine/`,
    `vendor/`. Two repositories implementing one contract are a different case, because the build
    is
    the only thing that separates them and the role word is already taken by both.

    `transport-picoquic`, which RFD 2111 renamed from `fabric-edge`, is the precedent for naming a
    transport repository after its stack, taken for the same reason: "Bare `transport` would read
    as a
    name that went missing."

    The language outlives the library. Swapping picoquic for another C QUIC stack, or
    `pywebtransport`
    for aioquic, leaves both names true, where `-picoquic` and `-pywebtransport` would strand.
    """

    details "What is built", ~S"""
    Both repositories carry the conformance gate and the terminator, on `aioquic` 1.3.0 and
    `iceoryx2` 0.9.3, and neither carries a cross-test.

    `conformance.py` decodes all 64 golden vectors, checks the fields the CSV names, and
    re-encodes to
    compare byte for byte. `--self-test` corrupts one vector and the gate is wrong if that passes.
    CI
    runs both, on every pull request and in the merge group.

    `transport-ingest-python` was driven end to end on a live session with an EC P-256 server key:
    CONNECT answered `:status 200`, three records in one datagram reached the ring byte-identical
    to
    the wire, and a 250-byte datagram was dropped whole rather than trimmed to two records.

    The live cross-test against the C pair is not written, and there is nothing yet to write it
    against. `transport-gateway-c` and `transport-ingest-c` have no `main` and no
    `CMakeLists.txt`, and
    both READMEs say "State: not started". `transport-ingest-c`'s copy of the transport code is a
    stale
    fork of `transport-gateway-c`'s: it passes an `h3zero_callback_ctx_t` where `h3zero_callback`
    casts
    to `picohttp_server_parameters_t`, and it lacks the `h3zero_declare_stream_prefix` call. That
    divergence is the reason both Python repositories consume one emitted codec rather than two
    copies.
    """

    drafted_by :ai
  end
end
