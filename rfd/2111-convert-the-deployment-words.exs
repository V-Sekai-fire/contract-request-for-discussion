# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2111. `mix rfd.render` renders rfd/2111-convert-the-deployment-words/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2111 do
  use RFD.DSL

  rfd 2111, "Convert the deployment words" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    RFD 2028 made every component a hexagon with a `core/` + `ports/` +
    `adapters/` layout. It took the pattern from Cockburn and added four
    words that Cockburn does not use: core, domain logic, edges, and the
    `*_source` / `*_sink` pair.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Convert the deployment words"

    details "Context and problem statement", ~S"""
    RFD 2028 made every component a hexagon with a `core/` + `ports/` +
    `adapters/` layout. It took the pattern from Cockburn and added four words
    that Cockburn does not use: core, domain logic, edges, and the `*_source` /
    `*_sink` pair.

    A second vocabulary grew later, in code rather than in an RFD. The `Weft`
    moduledoc in `fabric-weft-plane` defines plane, edge plane, and domain. Ten
    or more READMEs repeat those definitions. `fabric-zone-domain` and
    `fabric-behaviour-domain` carry the same sentence word for word.

    `fabric-harness` states the risk in its own README: a decision written twice
    drifts, and the stale copy still reads as authoritative. `Weft.VocabularyTest`
    exists to catch that. It reads the files of one git repository only, and it
    finds only retired words, so a live word with two meanings is invisible to it.
    """

    details "Decision drivers", ~S"""
    - ASD-STE100 permits one meaning for one word. RFD 2000 applies STE to all
      prose here.
    - `Weft` states the same rule, and applied it once already. Khronos CATSG
      says "entity" for the controlling human or AI. weft says "controller",
      because entity already names the simulated unit.
    - Cockburn writes about the inside of one component. He gives no word for a
      process or a machine. Netflix writes about the same inside, in the
      microservice framing, and gives nouns this stack can use.
    - Two names for one component cost more than the deployment words earn. A
      reader of `fabric-authority-plane` has to learn that a plane is a process,
      that the process holds a tick, and that the tick is what RFD 2028 calls
      the inside. One name removes two of those steps.
    """

    details "The Netflix terms", ~S"""
    The article defines five terms. Each quotation below is from it.

    | term            | definition                                                                                               |
    | --------------- | -------------------------------------------------------------------------------------------------------- |
    | Entity          | "domain objects (e.g., a Movie or a Shooting Location), they have no knowledge of where they're stored" |
    | Repository      | "interfaces to getting entities as well as creating and changing them"                                   |
    | Interactor      | "classes that orchestrate and perform domain actions"                                                    |
    | Data source     | "adapters to different storage implementations"                                                          |
    | Transport layer | "can trigger an interactor to perform business logic. We treat it as an input for our system"            |

    The rule that holds them together is that all dependencies point inward.
    """

    details "The conversion", ~S"""
    | retired word | replacement     | why the replacement fits                                                    |
    | ------------ | --------------- | --------------------------------------------------------------------------- |
    | plane        | interactor      | a plane holds entities and the actions on them, and it holds no transport   |
    | edge plane   | transport layer | an edge plane terminates a transport and triggers an interactor             |
    | domain       | service         | the microservice is the unit that deploys, and the ring decides its members |
    | store plane  | data source     | it implements repositories over FoundationDB and SQLite                     |

    "Service" is the weakest of the four, because the Netflix article names
    microservices without defining one. It is the only deployment word the
    formulation has, and the ecosystem uses it the same way. This RFD takes it
    and states the local meaning: a service is the set of interactors that share
    a ring.
    """

    details "One name for one concept", ~S"""
    | word            | the one meaning                                           | source   |
    | --------------- | --------------------------------------------------------- | -------- |
    | entity          | one simulated thing in a zone, with position and velocity | weft     |
    | repository      | an interface that gets, creates, and changes entities     | Netflix  |
    | interactor      | a process that performs actions on entities               | Netflix  |
    | data source     | an implementation of a repository                         | Netflix  |
    | transport layer | the input that triggers an interactor                     | Netflix  |
    | service         | the set of interactors that share a ring                  | Netflix  |
    | contract        | what two sides compose against, checked at the seam       | weft     |
    | ring            | the iceoryx2 shared memory bus                            | weft     |
    | port            | a TCP or UDP listening socket                             | ordinary |
    | actor           | a runtime process with a single writer                    | weft     |
    | controller      | the human or the AI that controls an avatar               | weft     |

    "Contract" is not one of the five Netflix terms, and this RFD adds it. The
    article has no word for the interface an interactor and a transport both
    compose against, because it writes about classes inside one component rather
    than about git repositories that must build without each other. The word is
    weft's and it is already load-bearing here: `PredictiveBvh.core.CurveContract`
    asserts a property against whatever the manifest pins, and
    `fabric-interactor`'s README says the boundary is held by the linker. Both are
    the agreement at a seam, checked rather than assumed, so one meaning covers
    them.

    weft and Netflix agree on "entity". Netflix says an entity does not know
    where it is stored. weft says an entity is the unit the data plane moves.
    Both keep the entity away from its storage, so one meaning covers both.
    """

    details "Where the terms land in this stack", ~S"""
    | the thing that exists today                        | the word for it |
    | -------------------------------------------------- | --------------- |
    | `XRGridEntityPacket` from `lean-entity-packet`     | entity          |
    | `src/authority_tick.c` in `fabric-authority-plane` | interactor      |
    | the reducer in `combat`, the roll in `loot`        | interactor      |
    | `fabric-gateway-edge`, `fabric-ingest-edge`        | transport layer |
    | `Weft.Actor.Store`, the store API                  | repository      |
    | FoundationDB behind the SQLite VFS                 | data source     |
    | `fanout_sink_t` in `fabric-fanout-edge`            | repository      |
    | the WebTransport sink behind it                    | data source     |
    | a recorded fixture under CI                        | data source     |
    | the members of `fabric-zone-domain`                | one service     |

    `fabric-fanout-edge` shows that the pattern is in the code already. Its
    README says that a WebTransport sink can replace the default sink, and that
    nothing above it changes. That is one repository with two data sources.
    """

    details "The collisions this resolves", ~S"""
    The word "domain" had three meanings: the deployment packing, the "domain
    logic" of RFD 2028, and a field on the wire in RFD 2091. The first becomes
    "service". The second becomes "entity" and "interactor". The third needs its
    own decision, because a change on the wire is a protocol change.

    The word "edge" had two meanings. RFD 2028 said "concrete I/O at the edges",
    and an edge plane was a process. RFD 2028 now says "outside the interactor",
    and the process is a transport layer. No meaning is left to collide.

    The word "port" had two meanings. Netflix uses no word "port", so the
    listening socket keeps it, and `fabric-zone-domain` needs no edit.
    """

    details "The collision this creates", ~S"""
    Netflix says "repository" for an interface to entities. This project says
    "repository" for a git repository, in RFD 2000, RFD 2062, RFD 2063, and
    RFD 2064. That is a new word with two meanings, and this RFD makes it.

    The resolution is to write "git repository" in full every time, and to keep
    "repository" alone for the interface. Keeping Cockburn's word "port" for the
    interface would avoid this, and it would revive the collision with the
    listening socket, which is in the code of every transport layer. A collision
    in prose costs less than a collision in code.
    """

    details "What \"plane\" keeps", ~S"""
    "Control plane" and "data plane" stay whole. They come from networking, they
    name a class of traffic, and neither one names a process. `Weft.DataPlane`
    keeps its name. Bare "plane", as a noun for a process, is retired.
    """

    details "The name shape", ~S"""
    A converted name puts the type first and drops the `fabric-` prefix:
    `<type>-<name>`. `fabric-authority-plane` becomes `interactor-authority`.

    Type first sorts the git repositories by role. Every interactor is then
    adjacent, and the number of each type is the length of a run, so the list
    above can be read off the organisation page. Type last sorted them by
    subsystem, which kept `fabric-store-domain` beside `fabric-store-plane` and
    put the seven planes in seven places. One order is available or the other,
    not both, and role is what a reader of this RFD is looking for.

    The `fabric-` prefix goes because the organisation name already carries it.
    That also frees the bare word, which one git repository takes below.
    """

    details "The rename list", ~S"""
    Thirty git repositories are renamed: twenty-five carry a retired word, three
    carry the right word in the wrong order, and two state a type that is not
    theirs.

    | now                            | after                       |
    | ------------------------------ | --------------------------- |
    | `fabric-authority-plane`       | `interactor-authority`      |
    | `fabric-crowd-plane`           | `interactor-crowd`          |
    | `fabric-janet-plane`           | `interactor-janet`          |
    | `fabric-motion-plane`          | `interactor-motion`         |
    | `fabric-taskweft-plane`        | `interactor-taskweft`       |
    | `fabric-tool-plane`            | `interactor-tool`           |
    | `fabric-weft-plane`            | `interactor-weft`           |
    | `gyreplane`                    | `interactor-gyre`           |
    | `fabric-physics-interactor`    | `interactor-physics`        |
    | `fabric-asset-edge`            | `transport-asset`           |
    | `fabric-fanout-edge`           | `transport-fanout`          |
    | `fabric-gateway-edge`          | `transport-gateway`         |
    | `fabric-ingest-edge`           | `transport-ingest`          |
    | `fabric-edge`                  | `transport-picoquic`        |
    | `fabric-behaviour-domain`      | `service-behaviour`         |
    | `fabric-store-domain`          | `service-store`             |
    | `fabric-zone-domain`           | `service-zone`              |
    | `fabric-godot-service`         | `service-godot`             |
    | `fabric-physics-service`       | `service-physics`           |
    | `fabric-store-plane`           | `datasource-store`          |
    | `fabric-flow-adapters`         | `datasource-flow`           |
    | `fabric-flow-adapters-project` | `datasource-flow-project`   |
    | `lean-combat-core`             | `entities-lean-combat`      |
    | `lean-loot-core`               | `entities-lean-loot`        |
    | `lean-progression-core`        | `entities-lean-progression` |
    | `lean-rebac-core`              | `entities-lean-rebac`       |
    | `lean-shared-core`             | `entities-lean-shared`      |
    | `fabric-godot-core`            | `entities-godot`            |
    | `fabric-interactor`            | `contract-command`          |
    | `fabric-service-meta`          | `fabric`                    |

    GitHub redirects a renamed git repository, so a `git subtree` remote and a
    Lake `require ... from git` continue to resolve. Each pin gets updated in the
    same pass.

    Three git repositories hold the RFD 2028 triad on disk: `loot`, `combat`,
    and `progression`. Each `core/` becomes `entities/`, each `ports/` becomes
    `repositories/`, and each `adapters/` becomes `datasources/`.
    """

    details "The names the shape does not decide", ~S"""
    Six entries above do not follow from the conversion table, and each one is a
    decision this RFD makes rather than a rule it applies.

    `fabric-edge` holds both an ingest edge and a gateway edge over picoquic,
    and the two also exist as git repositories of their own. It is one transport
    layer that the other two are built from, not an umbrella over them, so it
    takes the name of the transport it terminates: `transport-picoquic`. Bare
    `transport` would read as a name that went missing.

    `gyreplane` carries the retired word inside a compound. It is a process that
    holds entities, so the word is retired there as well, with the name
    regularised to `interactor-gyre`. A compound is not an exemption.

    `fabric-flow-adapters` and its `-project` companion carry RFD 2028's
    "adapters", which this RFD retires for directories. The retirement extends to
    git repository names. A word retired in the tree and live in the name is the
    same drift this RFD exists to stop, and the name is the copy a reader sees
    first.

    `fabric-godot-core` becomes `entities-godot`, and the rename is of the git
    repository name only. The `core/` directory inside it is the Godot engine's,
    it comes from upstream, and it is not the "core" of RFD 2028. Renaming it
    would fork the vocabulary of an engine this project tracks rather than owns.

    `fabric-interactor` is not an interactor. It holds the contract that
    interactors and transports compose against, `include/weft/interactor.h`
    declares both, and its README states the reason it is a git repository of
    its own: "a contract that lives in either side makes the other its
    dependent". A name of `interactor-anything` picks the side the git
    repository exists to avoid picking. The type is contract for the subject, the command, so it
    is `contract-command`. "Contract" is the one type word
    here that Netflix does not supply, and the entry above says where it comes
    from. `fabric-harness` is the same argument about the bus and the limits, and
    becomes `contract-bus` when that pass is taken.

    `fabric-service-meta` is not a service. It holds the `.meta` manifest that
    names every git repository here, and the conventions over them. `service-meta`
    would assert the thing that is false, and `meta` alone collides with a company
    that owns the word in every search. It takes the bare `fabric`, which the
    dropped prefix frees: after this pass the word is in one name, and that name
    is the git repository the other names are listed in. `openusd-fabric` keeps
    the OpenUSD scene-data meaning and keeps its qualifier, the same resolution
    this RFD uses for "git repository".

    Fourteen `lean-*` git repositories are not hexagon cores, and they keep the
    language-first name while five siblings move. `lean-` marks a Lean workspace
    that this RFD does not classify. The convention applies where there is a word
    for the thing, and nowhere else.
    """

    details "Considered and rejected: the agent noun", ~S"""
    "Interactor" was challenged on the ground that RFD 2000 applies ASD-STE100,
    that STE forbids a nominalized verb, and that "interact" fails to
    discriminate, because a transport layer and a data source interact as well.
    Both objections hold. The word is kept anyway.

    The alternatives were checked against the words this workspace already uses,
    across every checkout. `tick` appears 1091 times and this RFD itself says the
    process holds a tick. `warp` collides with the GPU warp in `SIMT.lean` and
    with the MJX-Warp tree vendored inside the physics git repository. `cell`
    appears 2651 times, `kernel` 8615, and `shard` 663. `hexagon` is already the
    house word for the code shape, and a transport layer has that shape too, so
    it recreates the collision this RFD closes. `loom` was the only clean
    candidate at zero uses, and it is a metaphor that would have to be taught.

    Netflix supplies "interactor", two git repositories already carry it, and a
    word with a stated weakness costs less than a word this project invents. The
    objection is recorded here so that the next reader of eight new names finds
    it answered rather than open.
    """

    details "A gap this pass found", ~S"""
    The `lean-*-core` READMEs state a "Hexagon layout" of `core/`, `ports/`, and
    `adapters/`. Those directories do not exist. Each of those git repositories
    holds one Lean namespace directory, such as `Shared` or `Rebac`. The
    documents describe a layout that no git repository has. The rename pass
    corrects the READMEs to the directories that are there.
    """

    details "Consequences", ~S"""
    - One component has one name. A reader learns one vocabulary.
    - Each word has one meaning, and STE holds across the git repositories.
    - The definitions leave the READMEs and live here, so the copies stop
      drifting.
    - `Weft.VocabularyTest` gains the retired words: plane, edge plane, domain,
      core, domain logic, and adapters. The test then holds this decision. The
      entries for "control plane" and "data plane" must not match, so the pattern
      needs a word boundary and a check for the preceding word. "Core" needs the
      same treatment, because `fabric-godot-core`'s `core/` directory is upstream's
      and must not match either.
    - The test reads one git repository, so it holds the decision only where it
      runs. Thirty git repositories are renamed here and one of them can hold a
      copy of the definitions, which is the arrangement the test cannot check.
      That gap is not closed by this RFD.
    - The rename touches thirty git repository names, three directory triads, and
      every README that copies a definition. Every one is mechanical, and none
      changes a build.
    - Twenty-five of the thirty carry a retired word. The other five do not, and
      a reader will not predict them from the conversion table.
      `fabric-physics-interactor`, `fabric-godot-service`, and
      `fabric-physics-service` are already converted and are renamed for the order
      alone. `fabric-interactor` and `fabric-service-meta` state a type that is
      not theirs, which the conversion table cannot catch, because it looks for
      the words that are wrong rather than for the words that are misapplied.
    - This RFD does not rename the `domain` field on the wire in RFD 2091. That
      is a protocol change and needs its own RFD.
    """

    drafted_by :ai
  end
end
