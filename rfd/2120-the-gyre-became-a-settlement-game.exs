# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2120. `mix rfd.render` renders rfd/2120-the-gyre-became-a-settlement-game/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2120 do
  use RFD.DSL

  rfd 2120, "The gyre became a settlement game" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    | | RFD 2085 | `service-store` | | ---------- |
    --------------------------------- |
    ----------------------------------------------- | | The player | A
    Spark taking contracts | The Queen, commissioning venues | | The loop
    | Hub, field, return | Commission, then wait a cycle | | The map | Six
    zones to travel | Six venues on two decks | | Contracts | Taken by the
    player | Chosen by Sparks, resolved against risk | | Currency | Chits
    | Scrip | | Antagonist | Overseer Q-11 | The Debt Clock, compounding
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "The gyre became a settlement game"

    details "What changed, line by line", ~S"""
    |            | RFD 2085                          | `service-store`                                 |
    | ---------- | --------------------------------- | ----------------------------------------------- |
    | The player | A Spark taking contracts          | The Queen, commissioning venues                 |
    | The loop   | Hub, field, return                | Commission, then wait a cycle                   |
    | The map    | Six zones to travel               | Six venues on two decks                         |
    | Contracts  | Taken by the player               | Chosen by Sparks, resolved against risk         |
    | Currency   | Chits                             | Scrip                                           |
    | Antagonist | Overseer Q-11                     | The Debt Clock, compounding one percent a cycle |
    | Combat     | One of nine, avoidable            | One of nine, avoidable                          |
    | Failure    | Death, and a dropped Memory Drive | Wear, capped, and a Frame that stops earning    |

    The last two rows are what survived intact.
    """

    details "The venues, and what each one does", ~S"""
    | Venue                | Cost | Effect                                        |
    | -------------------- | ---- | --------------------------------------------- |
    | Cycle's End Tavern   | 120  | Rest, so a Spark takes longer odds            |
    | Splicer's Den        | 200  | Frames repaired, so wear stops ending careers |
    | Transit Rails        | 260  | More contracts reach the board                |
    | Exchange Plaza       | 340  | Salvage sells for what it is worth            |
    | Chapel of the Backup | 420  | A failure costs a cycle rather than a Spark   |
    | Broadcast Row        | 500  | Word gets out, and Sparks arrive              |

    A venue changes behaviour rather than adding a number. The Tavern and the Chapel raise the
    nerve a Spark brings to a
    contract, the Den takes wear back faster than rest does, the Rails widen the board, and the
    Row is the only source of
    new Sparks. Each is a decision about what kind of ward this becomes.
    """

    details "The numbers the ward holds", ~S"""
    A ward starts with a treasury of 300 against a debt of 4000. Debt compounds at one percent a
    cycle, and what the
    treasury can spare pays it down and counts as retired. A contract that succeeds pays its
    posted amount, and that is
    the only event that issues scrip.

    Wear rises by 2 on a success and 5 on a failure, falls by 1 for the cycle's rest, falls a
    further 4 where the Den
    stands, and is held between 0 and 90. Nerve is 100 less wear, plus 25 with the Tavern and 20
    with the Chapel. A Spark
    with no nerve for anything on the board stands idle.

    Somebody hears the Broadcast Row every 12 cycles. The arrival counts cycles rather than
    drawing, so a replay puts the
    newcomer in the same place.

    A ward holds at most 48 Sparks, because a subscriber's slice holds 64 entities and the venues,
    the Queen and a full
    board come out of that budget first. A larger ward is refused, and a game past that size is
    more than one ward, to a
    limit of eight.
    """

    details "Why the shape changed", ~S"""
    The comment at the top of `src/queen.c` gives the reason directly. A settlement game is a
    state machine over days with
    nothing in the critical path to draw, which makes it the one game shape genuinely better as a
    database than as an
    engine. The Queen commissions and waits, so a cycle is a transaction and the whole of the
    visible state is a query.

    The MUD shape needed a room, a description, and a player standing in it, none of which a store
    plane exercises. The
    settlement shape gave `service-store` a workload that is exactly the thing the store plane
    claims to be good at:
    N Sparks is N databases committing every cycle, and paying one is a transfer between two of
    them under the parallel
    commit protocol.
    """

    details "What this leaves open", ~S"""
    Whether the Spark-facing game returns. Nothing here forecloses it, and RFD 2119 assumes it
    does, with hands and
    salvage in a headset. The ward would be the economy underneath it rather than the whole of it.

    Whether Memory Drives arrive with that, since they are the one adversarial interaction the
    setting describes and the
    one object whose duplication is unsurvivable in the fiction.

    Whether the absent zones come back as places, given that venues, Sparks and contracts already
    carry coordinates in
    micrometres for the interest filter.
    """

    details "What has not been built", ~S"""
    The Reclamation Wards, the Tangle, the Sub-Net and the Underhull have no representation in the
    ward. Splicer Jax,
    Overseer Q-11 and Rook are absent, though the Splicer's Den carries Jax's role as a venue.
    Memory Drives, and the
    looting and ransoming of them, are unimplemented, which matters because they are the setting's
    one adversarial
    interaction and RFD 2119 turns on them.

    These stay in 0085 as setting. This RFD narrows what `service-store` claims to simulate rather
    than retiring
    the fiction around it.
    """

    details "Consequences", ~S"""
    0085 remains the setting record and stops being the design record for the ward. A reader who
    wants to know what the
    simulation does reads this one.

    The salvage and interaction model in RFD 2119 sits on the cycle boundary rather than on a Hub
    and Field loop, because
    the loop it was written against is not the loop that exists.
    """

    drafted_by :ai
  end
end
