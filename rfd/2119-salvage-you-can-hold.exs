# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2119. `mix rfd.render` renders rfd/2119-salvage-you-can-hold/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2119 do
  use RFD.DSL

  rfd 2119, "Salvage you can hold" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    | | Loose, between cycles | Claimed, at the cycle | |
    ------------------ | ------------------------------------------ |
    ------------------------------------- | | Enforced by | Ownership
    sequence number, host arbitrates | Transaction across two databases |
    | Cost | Nothing. Rides in the state update | About one round trip | |
    Wrong for | A few frames, then converges | Never | | Checked by |
    Convergence | `honest()`, every cycle | | Failure looks like | A crate
    snaps to another pose | Scrip or salvage that does not add up |
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Salvage you can hold"

    details "One invariant at two consistency levels", ~S"""
    |                    | Loose, between cycles                      | Claimed, at the cycle                 |
    | ------------------ | ------------------------------------------ | ------------------------------------- |
    | Enforced by        | Ownership sequence number, host arbitrates | Transaction across two databases      |
    | Cost               | Nothing. Rides in the state update         | About one round trip                  |
    | Wrong for          | A few frames, then converges               | Never                                 |
    | Checked by         | Convergence                                | `honest()`, every cycle               |
    | Failure looks like | A crate snaps to another pose              | Scrip or salvage that does not add up |

    The two rows describe the same rule. What differs is the price paid for it and how long it may
    be violated.
    """

    details "What Fiedler's model supplies", ~S"""
    Authority passes to whoever last interacted with an object, and ownership stops a second
    player taking it while it is
    held. Both ride as sequence numbers in every state update, and the host accepts an update when
    its sequence is newer.
    Conflicts are reported as rare in practice even under significant latency.

    State is quantized identically on both sides before each physics step, at 1/1000th of a
    centimetre, and synchronized
    at 10 Hz against PhysX's non-determinism. A priority accumulator decides which objects fit in
    each packet, boosting
    whatever collided or was recently thrown, which gives direct control over bandwidth against a
    fixed packet size. Delta
    compression against per-object baselines encodes an unchanged object in one bit and a
    ballistic-predicted object in
    one more. Four players fit under 256 kbps each.

    A held object leaves the physics stream entirely and rides in the holder's avatar packet as a
    relative transform,
    which stops the hand and the object disagreeing. Avatar state arrives through a 100 ms jitter
    buffer.
    """

    details "What the Gyre supplies", ~S"""
    The ward is a SQLite database over a VFS whose pages live in FoundationDB, and every Spark is
    a database of their own.
    Paying one is a transfer between two databases under the parallel commit protocol. Three
    invariants hold every cycle:
    scrip is conserved, salvage is unique, and one seed makes one ward.

    The third is what constrains this design most. A cycle may not advance on wall-clock time, and
    no change may alter the
    RNG draw order, because `check` plays a seed twice and compares a fingerprint. A physics
    simulation that fed the ward
    would end that check, and PhysX is the reason Fiedler rejected lockstep in the first place.
    """

    details "What PRAGMATA supplies", ~S"""
    Two characters played at once: Hugh moves, shoots and jumps while Diana hacks in real time.
    The interest is in the
    division of attention rather than in either half alone.

    The Gyre has both halves already. Hands work at frame rate, and the Queen's board of
    contracts, venues
    and cycles runs as a discrete layer that decides what the object in a hand is worth. The claim
    is the moment the two
    layers touch.
    """

    details "The Memory Drive as the worked case", ~S"""
    RFD 2085 has Memory Drives housing a Spark's consciousness, dropping on death, and available
    to be looted or ransomed.
    Every property that makes an object hard here is present at once. It is holdable, so it wants
    distributed authority.
    It is contested between players who benefit from taking it, so it cannot have distributed
    authority. It is unique in
    the fiction as strongly as in the ledger, because duplicating a drive duplicates a person.

    The split resolves it. The shell is a physics object under the ordinary rules, and custody is
    a row that moves only by
    transaction. A player can carry, drop and hand over the shell at frame rate while the question
    of who owns the drive
    is answered somewhere that cannot be raced.
    """

    details "Failure modes to design against", ~S"""
    A claim that inserts before it deletes duplicates the item for the width of the window. A
    claim that deletes before it
    inserts destroys it for the same width. The parallel commit exists to make both halves land
    together, and the claim is
    exactly the transaction it was built for.

    An object committed by a cycle and still simulated afterwards exists twice, with the ledger
    aware of one copy. This
    shows up as a violated invariant on the next cycle rather than as a visual artefact, which is
    the reason to prefer
    this arrangement over one that reconciles later.

    Distributed authority over anything priced in scrip lets a player take what they were not
    given. This is the whole
    content of Fiedler's cooperative-only caveat applied to a setting that has an economy.

    Physics feeding the seeded simulation ends the replay check silently. Nothing fails at the
    moment it happens, and
    `check` starts disagreeing with itself on runs that used to match.
    """

    details "Alternatives considered", ~S"""
    Server-authoritative physics with client-side prediction. This removes the security caveat and
    the split, at the cost
    of rollback and resimulation for every interaction, and of a round trip in the hands of a
    player holding an object.
    Fiedler weighed the same trade and observed that for this class of interaction the security is
    effectively the same
    either way, since the client is trusted about its own hands regardless.

    One consistency level for everything, chosen as the strong one. Every crate becomes a
    transaction, and throwing
    anything costs a commit. This holds every invariant and gives up the interaction the RFD
    exists to enable.

    One consistency level for everything, chosen as the weak one. Scrip and drives converge like
    cubes do. This is fast,
    simple, and hands the treasury to whoever writes a client.

    Deterministic lockstep across all clients. This gives exactness without a ledger, and requires
    a deterministic physics
    engine the stack does not have.
    """

    details "TL;DR", ~S"""
    ```
    gyre X networked physics in vr X pragmata
    ```

    The Gyre supplies an economy a database can prove. Networked physics in VR supplies hands that
    pass an object between
    two people across a network. PRAGMATA supplies the shape of playing both at once.
    """

    details "Consequences", ~S"""
    The 100-byte entity packet and the interest filter in `transport-fanout` become the physics
    transport, which is what
    they were built for. `interactor-authority`'s single writer keeps the ledger and holds no
    opinion about where a
    crate is.

    Two representations of one object exist while it is loose, and exactly one exists once it is
    claimed. A bug in the
    conversion surfaces as a violated invariant on the next cycle rather than as a visual glitch,
    which is the failure
    mode to want.

    The second layer runs against the board the Queen already plays, so it costs content rather
    than architecture.
    """

    details "Open questions", ~S"""
    Whether the host-arbiter topology survives a dedicated ward process. Fiedler's host is a
    player; `queen serve` is not,
    and it already terminates WebTransport in its own process.

    What a claim costs in latency, given it is a parallel commit across two databases while the
    player is holding the
    object.

    Whether a drive's physical shell can be thrown at all while its custody stays transactional,
    or whether the shell has
    to be inert to keep the two from disagreeing.
    """

    drafted_by :ai
  end
end
