# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2112. `mix rfd.render` renders rfd/2112-lexical-for-the-slash-command-interface/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2112 do
  use RFD.DSL

  rfd 2112, "Lexical for the slash command interface" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    `fabric-store-domain/src/queen.c` is the Queen of the Gyre. Its
    `main()` takes `play|check <cycles> [seed] [sparks]`, founds a ward,
    runs the cycles, prints a chronicle, and exits. There is no socket, no
    server, and no instance that outlives the run. The README says the
    same thing from the other side: the game has no renderer, no client,
    and no engine, and what you can see of it is what you can `SELECT`.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Lexical for the slash command interface"

    details "Context and problem statement", ~S"""
    `fabric-store-domain/src/queen.c` is the Queen of the Gyre. Its `main()` takes
    `play|check <cycles> [seed] [sparks]`, founds a ward, runs the cycles, prints a chronicle, and
    exits. There is no socket, no server, and no instance that outlives the run. The README says
    the same thing from the other side: the game has no renderer, no client, and no engine, and
    what you can see of it is what you can `SELECT`.

    A slash command interface needs a live game and a place to type into. Neither exists yet.

    The typing part is the harder half. When a player types `/commission`, the field must show the
    parameter as an inline block that the player cannot edit, with editable space around it. An
    `<input>` and a `<textarea>` hold plain text, so neither can show such a block. A
    `contenteditable` element can. Written by hand it fails on the caret, on mobile autocorrect,
    on
    IME composition, and on paste, and it fails in the input path of every command.
    """

    details "Decision drivers", ~S"""
    - The interface is the input path of every command. A caret fault there stops play.
    - The framework must have production use at scale for more than one year.
    - Mobile keyboards and IME software are the hardest part of a `contenteditable` element, and
      they are the part a small project cannot test alone.
    """

    details "The two candidates", ~S"""
    |                            | Lexical                                                              | ProseMirror                                                    |
    | -------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------- |
    | Origin                     | Meta                                                                 | Marijn Haverbeke                                               |
    | Runs in                    | Facebook, WhatsApp Web, Workplace                                    | Atlassian, The New York Times                                  |
    | Model                      | a state model away from the DOM, with decorator nodes                | a schema and a transaction model, with atom nodes              |
    | Shape it targets           | short chat input, with mentions and emoji                            | long documents                                                 |
    | Caret across a block       | the decorator node is one block, and the caret crosses it            | the atom node can hold the caret, and a plugin must correct it |
    | Mobile and IME             | built for aggressive autocorrect and composition in chat             | reliable for text, weaker around complex inline nodes          |
    | Production time            | passes                                                               | passes                                                         |
    | Work with a language model | poor, because the v0.x API moves and models confuse it with Draft.js | good, because the API is stable and well represented           |
    """

    details "Decision outcome", ~S"""
    Lexical wins on the interface, and loses on developer speed. The interface decides, because
    this field is the input path of the game and the developer cost is paid once.

    ProseMirror is the stronger choice for a team writing boilerplate with a language model. That
    advantage does not reach the player. A caret that sticks on a parameter block does reach the
    player, on every command.

    The mitigation is written into the work. The `lexical` and `@lexical/*` versions are pinned
    exactly, the official documents are the source, and any prompt to a language model carries the
    current API in the prompt itself, because a model answers from an older version otherwise.
    """

    details "One instance of the ward", ~S"""
    The game runs as one instance. Every player sees the same ward, and a command from one player
    changes what all of them see. `found_ward` drops and recreates every table, so `/restart`
    re-founds the ward for everyone at once.

    One instance follows from the code rather than from a preference. `open_db` sets
    `PRAGMA locking_mode=EXCLUSIVE`, and the Queen is the single writer of the ward. The Fly app
    therefore stays one machine, which is the shape `min_machines_running = 1` and
    `auto_stop_machines = false` already describe elsewhere in the org. The client bundle is
    immutable, so whatever serves it scales without limit. Separating the two is what lets each
    follow its own rule.
    """

    details "The ward as a zone, and its rows as entities", ~S"""
    The Queen's rows are entities, and they take spatial coordinates. That puts the ward inside
    the
    zone and entity model the rest of the stack already uses, and it makes the interest filter
    apply to this game without inventing anything.

    | the row in `queen.c`              | count                                       | what it becomes                          |
    | --------------------------------- | ------------------------------------------- | ---------------------------------------- |
    | a Spark, one SQLite database each | up to `MAX_SPARKS`, which is 64             | a moving entity, with a purse and wear   |
    | a venue from `VENUES`             | `NVENUES`, which is 6                       | a fixed entity at the place it was built |
    | the Queen                         | 1                                           | the authority, and the single writer     |
    | a contract on the board           | `BOARD_SIZE` 6, or 9 with the Transit Rails | a marker at the place the work is        |

    `spark_t` holds `id`, `purse`, and `wear` today, and no position. Adding `pos_um_x`,
    `pos_um_y`,
    and `pos_um_z` is the change that connects the two models, because those are the fields
    `XRGridEntityPacket` already carries in int64 micrometres.
    """

    details "How a local command becomes a global one", ~S"""
    The interest filter decides how many players see a change. RFD 2111 retires the word plane,
    and
    the filter lives in `fabric-fanout-edge`, which is a transport layer.

    `lean-interest-mgmt/core/AuthorityInterest.lean` separates authority from interest. Exactly
    one
    zone advances an entity each tick, and a neighbour holds a read-only ghost. An entity enters
    that neighbour's interest when its k-tick kinematic expansion overlaps the neighbour's volume,
    with `interestLookahead` of 6 ticks. Then `fabric-fanout-edge/src/fanout.cpp` filters per
    subscriber: `ghost_aabb_of` widens each entity by `ENTITY_EXT_UM` of 500000 and by
    `GHOST_TICKS` of 2 along its velocity, and `aabb_overlaps` tests that against
    `subscriber_t.interest`.

    So the reach of a command is the overlap between the entities it touches and the boxes the
    players hold. The Queen's own verbs cover the whole range.

    | command                  | what it changes in `queen.c`                  | how far it reaches                                                                          |
    | ------------------------ | --------------------------------------------- | ------------------------------------------------------------------------------------------- |
    | `look`                   | nothing                                       | The caller only. A read changes no entity, so the filter never runs.                        |
    | a Spark takes a contract | that Spark's position, as it goes to the work | Every subscriber whose box the Spark enters or leaves. This is the common case.             |
    | `/pay <spark>`           | one purse, in one Spark database              | Every subscriber whose box overlaps that Spark.                                             |
    | `/commission <venue>`    | `venue.built`, and the ward treasury          | The venue appears to every box that overlaps its place. The treasury reaches no box at all. |
    | `/restart`               | every table, through `found_ward`             | Every subscriber. No box excludes it.                                                       |

    The Spark taking a contract is the one to hold on to. It is local by intent, and the filter
    turns it into a message to an arbitrary number of players, because the Spark leaves one set of
    boxes and enters another. Neither the player nor the command knows how many that is.
    """

    details "Primary and secondary streams", ~S"""
    The ward is served the way a stream is served. One primary carries the live game. Secondaries
    carry the same ward to their own subscribers. When the primary goes, a secondary is hosted in
    its place, and a player may pick a secondary as a fallback while playing, so a promotion costs
    no reconnect.

    The relay tree in `fanout.cpp` is already this shape. Its header says each relay process runs
    the leaf for its own subscriber set on its own NIC, so aggregate egress scales with the relay
    count. A secondary is one of those leaves.

    The store plane supplies the promotion, and it needs no new mechanism.
    `thirdparty/store-plane/prove_handoff.c` proves the property the whole thing rests on: a
    database has no local file, so a different process reads it with no copy and no restore. A
    secondary therefore opens the same ward out of FoundationDB and is already current.

    | the stream idea                           | what it is in the ward                                                      |
    | ----------------------------------------- | --------------------------------------------------------------------------- |
    | the primary stream                        | the process holding the current fence, which is the only one that may write |
    | a secondary stream                        | a follower reading the same ward pages, holding no fence, writing nothing   |
    | hosting a secondary when the primary goes | the FENCE key moves, and the promoted process becomes the writer            |
    | a fallback chosen while playing           | a subscription to a second leaf, held open so promotion costs no reconnect  |
    | a viewer who switches away                | a subscriber held by a keepalive, with the slices stopped                   |

    The fence is what makes promotion safe. `check_fence` reads the FENCE key on every write
    transaction and refuses the write with `SQLITE_READONLY` when the value has moved. Its comment
    records why it exists: the VFS locks are no-ops, so two writers both believed they held the
    write lock, both reported success, `PRAGMA integrity_check` passed, and one writer's 300 rows
    were gone. The fence turns that into a refusal the caller can see. So an old primary that
    comes
    back after a promotion is refused rather than silently losing the ward.

    `PRAGMA locking_mode=EXCLUSIVE` in `open_db` does not block a promotion. `fdb_lock`,
    `fdb_unlock`, and `fdb_check_lock` all return success without doing anything, and the pragma
    is
    there to stop SQLite re-reading page one, which over a network database is a round trip per
    query. A dead primary holds nothing that a new one must break.

    A tab that goes to the background stops being worth sending to. The browser throttles a hidden
    tab and reports the change through `visibilitychange`, so the client stops asking for slices
    and
    holds the session with a keepalive. The leaf keeps the `subscriber_t` and sends nothing. When
    the tab comes back the slices resume, with no reconnect and no second authorization. RFD 2050
    already sets a five-second transaction limit, which is the natural place to start for the
    keepalive interval.

    The keepalive is also what makes a fallback cheap. A player picks a second leaf while playing
    and holds it by keepalive alone, so it costs a seat and no egress until the primary goes and
    the fallback starts sending. A fallback that streamed continuously would double that player's
    share of the cap in the next section.

    One thing is worth stating plainly. `queen` implements none of this today, and the fence lives
    in the VFS rather than in the game, so promotion is supported and unwritten.
    """

    details "Three hazards this exposes", ~S"""
    `MAX_SPARKS` is 64 and `MAX_SLICE_ENTITIES` is 64. Those two constants were written in
    different
    repositories for different reasons, and they are equal. A ward at full size therefore fills
    one
    subscriber's slice with Sparks alone, and `fanout_one` stops at the cap, so the six venues,
    the
    Queen, and every contract marker fall off the end. A full ward is 64 Sparks, 6 venues, the
    Queen, and up to 9 contracts, which is 80 entities against a cap of 64.

    The client cannot detect the loss. The receiver recovers the count as `len / 100`, so a
    truncated batch looks exactly like a small one.

    `/commission` shows the second hazard. It changes two things at once: a venue, which has a
    place, and the treasury, which does not. An interest box can carry the first and can never
    carry the second. The ward scalars `treasury`, `debt`, `issued`, `retired`, and `spent` are
    not
    spatial, and no `Aabb` describes them. They need the reliable control stream, and RFD 2049
    holds the channel classes for it.

    The third hazard follows from the second. `honest()` checks that
    `treasury + purses + retired + spent == issued` across the ward and every Spark database. That
    sum is global. A player holding one interest slice sees a few Sparks and cannot compute it, so
    the invariant stays a property the authority checks and the client takes on trust.
    """

    details "What serves it, and where", ~S"""
    `fabric-asset-edge` serves the built client on Fly. It is a transport layer, so it holds the
    listening socket. It shares nothing per tick, so it needs no ring, and it belongs to no
    service.
    That is the same reason its README already gives for standing alone.

    `queen` gains a transport layer of its own for the live game, because it has none today. RFD
    2111
    renames these git repositories, and the names here are the names on disk.
    """

    details "Findings that change the work", ~S"""
    | what was found                                                                                                         | consequence                                                                                                                                          |
    | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
    | `queen` is a batch program. `main()` plays cycles and exits, with no socket and no loop.                               | The live game has to be built before any client can attach.                                                                                          |
    | `spark_t` carries no position.                                                                                         | Coordinates are new fields, and the ward needs a map.                                                                                                |
    | `fabric-asset-edge` holds one h2o handler and no `main()`. There is no server loop, no Containerfile, and no fly.toml. | Serving anything from it means writing the server first.                                                                                             |
    | `GET /chunk/{hash}` answers `application/octet-stream` and 403s unless `rebac_check` passes.                           | The client needs its own route with real content types, and the public read has to be decided rather than a weakening of `resolve_caller_relations`. |
    """

    details "Implementation steps", ~S"""
    1. Give the Queen's entities coordinates. Add the position fields to `spark_t`, place the six
       venues, and place a contract at the work it names.
    2. Make `queen` a live instance. Keep `play` and `check` for CI, and add a served mode that
       holds the ward open and accepts commands.
    3. Add a bundler and the client to `fabric-store-domain`. Pin `lexical` and each `@lexical/*`
       package to an exact version.
    4. Add `CommandPillNode`, which extends `DecoratorNode` and draws the parameter block. Use the
       plain DOM decorator, because there is no React here.
    5. Add a plugin that opens the menu on `/` and inserts the blocks for the command the player
       picks. Filter the menu by the caller's rebac relations, so `/restart` stays hidden from a
       player who may not run it. The server checks again on receipt, because a filtered menu is a
       convenience and never an authorization.
    6. Write the server, the routes, and the Fly deploy in `fabric-asset-edge`.
    7. Raise `MAX_SLICE_ENTITIES`, or send venues on their own channel, before a ward runs at 64
       Sparks.
    """

    details "Verification", ~S"""
    The existing `check` mode already holds the game to its arithmetic, and it stays the gate: one
    seed makes one ward, and `honest()` runs inside every cycle. `docker compose run --rm ci` runs
    that against a real FoundationDB.

    For the interface, add Playwright tests for the caret crossing a block in one key press, for a
    block that cannot be edited in place, for backspace removing a block whole, and for the
    serialized command matching what the server accepts.

    Two constraints carry into any Fly app here. Every `*.fly.dev` host is on the HSTS preload
    list, so a browser upgrades the request to HTTPS and a 443 listener is required. An IPv6-only
    app can defeat Chromium's resolver where curl succeeds, so a test navigates to the bracketed
    IPv6 literal.
    """

    details "Consequences", ~S"""
    - The Queen gets a client, which the README currently records as absent.
    - `fabric-asset-edge` becomes a deployed transport layer, which it has never been.
    - The ward joins the zone and entity model, so the interest filter and the entity packet apply
      to it with no new mechanism.
    - Two constants that were independent are now coupled. `MAX_SPARKS` and `MAX_SLICE_ENTITIES`
      have to be read together from here on.
    - Lexical work costs more developer time per change than ProseMirror work costs.
    """

    drafted_by :ai
  end
end
