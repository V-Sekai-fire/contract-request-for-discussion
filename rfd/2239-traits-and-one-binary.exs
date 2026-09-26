# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2239. `mix rfd.render` renders rfd/2239-traits-and-one-binary/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2239 do
  use RFD.DSL

  rfd 2239,
      "Three efforts fold into the FBD teacher's traits, and the runtime ships as one binary" do
    state :discussion

    feature "the queued plan amended to its open items: dress-on, generate-pose and generate-identity become rows of the FBD teacher (ten traits at 100,000 rows, one generated anchor), the teacher's tools are ported to Elixir before any new trait, the DSL gains codebooks whose codes are enums, and the runtime with ggml inside ships as one native Godot binary"

    scope "`3-interactor/taskweft-fbd-teacher`, `3-interactor/taskweft-fbd-compiler`, `3-interactor/entities-godot-sandbox`, `3-interactor/voxhammer-upstream/tools`, the goal manifest `weftspun/weftspun-keypoint`"

    decision ~S"""
    A trait is a mixin: a named bundle of methods with a runner that performs
    them and a census that enumerates them; the compiler's signature tables
    and block sets are the bundles. Items 1, 2 and 4 of the operator's list
    fold whole into five new traits (DressOn, Spring, Identity, Body, and the
    generated DressEdit anchor) beside the six that exist. Every tool is
    ported to Elixir first, parsing rather than matching text; every seeded
    numeric is a code from a declared codebook; the trusted-source list
    bounds data, not code; and the runtime ships as one Godot binary with
    ggml as a module. `DETAILS.md` carries the rulings and their mechanisms.
    """

    problem ~S"""
    The operator queued a plan that keeps only open items, converts three
    efforts into dataset rows for the fourth, asks for Elixir over shell and
    Python, parsing over regex, reuse over new parts, and 100,000 items per
    trait. The existing plan mixed shipped and open work, the corpus tools
    were Python with regex parsers, free floats made distinct-program counts
    unknowable, and the runtime reached its models through servers.
    """

    references ~S"""
    - RFD 2229, interchangeable parts, the doctrine every leg is written against
    - RFD 2236, the teacher in three steps, whose corpus shape every trait keeps
    - RFD 2234, RFD 2237 and RFD 2238, the three efforts that fold into traits
    - RFD 2188, one ggml; RFD 2210, RFD 2215 and RFD 2230, the shipping surface the binary satisfies
    - RFD 2200, ReBAC tuples, amended with the `trusts` verb
    """

    related ~S"""
    RFD 2205 (the planner shim the binary hosts), RFD 2213 and RFD 2214 (the sandboxed VRM path and the model bundles), RFD 2196 (viewer rules the publisher follows).
    """

    details_title "Three efforts fold into the FBD teacher's traits, and the runtime ships as one binary"

    details "The operator's list, verbatim", ~S"""
    The queued plan (`fire/f8d642d9770f2e36ab64c9cda553acf3`, 2026-09-08):
    "amend the plan but peeling off completed items and keeping only open
    items. going to convert 1(dress-on),2(generate-pose),4
    (generate-identity) into dataset rows for 3 (fbd)"; "ladder improvements
    to the dsl if possible"; "Use elixir instead of shell or python
    scripting"; "Try to parse rather than regex if possible. See elixir
    sourceror library"; "Study our existing interchangable parts and use them
    before creating new parts"; "Dataset size must be 100_000 items per
    trait". The four scored items: dress-on 4, generate-pose 8, the MCP-ACP
    FBD teacher 8, generate-identity 2. The ReBAC trusted repositories:
    `huggingface.co/chibifire`, `v-sekai-fabric/weftspun-keypoint`,
    `chibifire/starforged-std-3001-appendix-e`.
    """

    details "The rulings and their mechanisms", ~S"""
    | ruling (operator, 2026-09-08) | mechanism |
    | --- | --- |
    | a trait is a mixin, "object oriented mix in style" | a signature table or block set is the bundle; a `CALL` or a block is the call; a family exercises one trait; DSL rung 2's `uses` line mixes several in |
    | peel none: items 1, 2 and 4 fold whole | DressOn, DressEdit, Body, Spring and Identity below; react and compose retire into Body |
    | "Port everything first": Elixir before any new trait | the `taskweft_fbd_teacher` app; each Python tool deleted after a scorer-parity smoke; a Python or shell file that survives is a runner wrapping a model and says so in its first line |
    | the trusted list bounds data sources; code repositories are fine | the `Trust` module gates every fetch and publish on `magi-16739d--trusts--<source>` tuples; forks are tooling; udon2godot's translations and the constraint-twist sample are constructed fixture inputs |
    | "FSQ categories become code enums", "like float categories rather than float numerics" | `codebook` declarations and `name#c.c.c` literals (DSL rung 1); an enum in Elixir, a `Fin` triple in Lean, an int triple in the guest; `Codebook.lean` proves the decode injective, bounded and monotone |
    | place the fashion set and the anthropometry table, then `repo sync` | manifest PR 129, merged at `a9a2f4fd`: three datasets under `6-datasource`, the motion-bricks bundle under `5-repository`, four pins moved |
    | "the entire system must run as a monolithic binary" with the ggml dependencies in `entities-godot` | `modules/ggml`, `modules/motionbricks`, `modules/taskweft`, `modules/game` and the sandbox pin advance in the Godot 4.7 fork; nothing at runtime reaches a Python, a WSL or a listener |
    | "interchangable parts methology is required. See also Japanese methods of industrial processes" | the RFD 2229 table per leg; jidoka, poka-yoke, genchi genbutsu, andon, takt, heijunka, kanban, 5S and kaizen each tied to a gate or a task rather than left as a slogan |
    | "double check .cff citations are updated every pass" | `mix fbd.cff.check` and the anti-entropy pair "manifest project against its `CITATION.cff`"; a citation line in every milestone's verification |
    | "elixir is a compentent binary parser too" | GLB, ONNX protobuf, gguf, `.npy` and parquet read by binary pattern matching, each reader with a refused control |
    | item 4's photo leg exists: the Speaking_Faces set, "convert to our methodology parquet and split into smaller datasets" | the conversion below; the re-host stays private until the likeness and consent RFD lands |
    """

    details "The traits", ~S"""
    | trait | the bundle | the quantity the runner reads back | today |
    | --- | --- | --- | --- |
    | Os | RUN, READ_FILE, WRITE_FILE steps | exit codes, files | 5,000 rows |
    | Blocks | the 28 block kinds of the scan set | the reference scan's per-tick outputs | 5,000 rows |
    | Body | the host's pad and tracker inputs; style, move, face, speed, 22 chain outputs | the reference scan, the sandbox differential, the live host's root translation | 5,000 rows under made-up names |
    | Plan | the planner's domains and exec kinds | the planner's steps, compared step for step | 5,000 rows |
    | Engine | the 60-entry engine table, 8 named uncovered | the engine's returns | 5,000 rows |
    | Trainer | the 38-entry trainer table | the trainer's term table | 5,000 rows |
    | Udon | translated fixture methods through udon2godot | Godot running the translated class | 5,000 rows |
    | DressOn | body, torso boxes, cameras, view pick, matte, composite, measure | metres, kilograms, box corners, pixels, coverage | none |
    | Spring | 22 per-chain masks over the Body inputs | tip step distance per chain per tick | none |
    | Identity | appendix-E cells, 11 phenotypes, 52 FACS action units, head fit, landmarks | metres, kilograms, landmark millimetres | none |
    | DressEdit (anchor) | the DressOn bundle plus splice and the two voxel controls | voxel far-containment | 12 targets shipped |

    Each row keeps RFD 2236's shape: a root intent, three candidates, scores,
    the joined view, three controls asserted on every row, splits by seed and
    by held-out subject. The four appendix-E cells, the gold evaluation
    garments, four FACS units and two whole Body templates are held out in
    every trait at once from one `holdouts.exs`, with a cross-trait leak
    pass before any 100,000-row run. Literal-free block kinds are capped at
    their exact space; the Blocks trait fills from the literal-bearing kinds.
    """

    details "The DSL ladder", ~S"""
    Rung 1, with this plan: `const` lines, `codebook` declarations and
    `name#c.c.c` literals, multi-output declarations, typed literal checks
    for signature arguments, a `--sigs <dir>` flag selecting a per-trait
    allowlist, `export-tables` as the one reader of the tables, `batch` for
    many jobs per process, an `ABS` block, and `# uncovered:` lines in the
    table header grammar. Rung 2, after Spring: array pins and `MUX` over an
    array, `uses <trait>` declarations checked by the netlist, `use
    <program>` composition. Rung 3, with RFD 2236's step 2: user function
    blocks. Each rung is a Lean change with an accepted and a refused fixture
    pair, the text-to-XML-to-text fixed point, and the Elixir printer
    mirrored the same day.

    A codebook is a mixed-radix index over three levels of eight, 512 codes,
    and the value is an affine image of the index over the rationals:
    `decode c = min + index(c)*(max-min)/(N-1)`. Reused from the
    recommender's Lean model: the stage index and its injectivity, bound and
    round-trip theorems. Not reused: the encoder side, whose value sum is not
    injective. A template's distinct-program space is then the product of its
    codebook sizes, and rank 3's first candidate is the neighbouring code,
    whose value differs by proof; whether the difference shows on the row's
    traces is still tried by simulation.
    """

    details "Trust, fixture inputs, inferred masks", ~S"""
    RFD 2200's verb table gains `trusts`. The tuples
    `magi-16739d--trusts--<source>` for the three trusted repositories are
    authoritative in Bao KV `relationships/`; `trust.exs` is derived from
    them and the pair is an anti-entropy check. Today the desk's certificate
    token has no read on `relationships/` (a 403 on the preflight check); the
    policy is not widened on a relay, so the tuples wait on the operator and
    the derived list serves meanwhile.

    A fixture input is a placed project a trait reads for its vocabulary or
    its skeleton and whose bytes no published row carries: the constraint
    twist sample (22 spring-bone chains) and the sandbox's translated `udon`
    set. They are not data sources and do not join the trusted list.

    An inferred mask (the matting model's alpha at a pinned revision) is
    permitted as an input to a constructed row on both arms when its
    provenance is recorded per row and the label is measured from the
    deterministic composite, never from the mask.
    """

    details "Item 4's photo leg", ~S"""
    The operator names the source: the Speaking_Faces set on the Hub
    (`issai/Speaking_Faces`, sha `eb2f8226`; paper DOI 10.3390/s21103465).
    142 subjects, nine camera positions, two trials of a silent and a
    command-reading session, a thermal stream at 464x348 and a visual
    stream at 768x512 with audio; 2.15 TB in 283 per-subject zips holding
    about 75,000 PNGs and 176 wavs per subject, already deflated; a subjects
    table with the authors' Train, Valid and Test split (100, 20, 22),
    age, gender, ethnicity and accessories. The project page releases the
    work under Creative Commons Attribution 4.0, the code under MIT, and the
    download points at the Hub with no registration form.

    The conversion is an Elixir task (`:zip` reader, Explorer writer) that
    streams one subject at a time (the desk has 1,278 GB free against 2.15
    TB) into per-subject, per-stream zstd parquet in normal form: a subjects
    relation with interned split, gender, ethnicity and accessory
    vocabularies; frames keyed by subject, trial, session, position, frame
    and stream with the PNG bytes as a binary column; utterances keyed by
    subject, trial, position, command and microphone. Three splits: the
    authors' Train is train, Valid is test, and Test is evaluation, held out
    by subject. Published as per-modality datasets under `chibifire`, private
    until the likeness and consent RFD lands, with a citation naming the
    paper, the licence page and the source sha. The leg calibrates and
    validates the head fit against real multiview photographs; no likeness
    ships, and the doctrine still rejects splicing a head onto the body. The
    population is narrow (90 Asian, 46 Caucasian, 6 Black subjects, ages 20
    to 64), which the card states, and which is why the set validates a fit
    rather than serving as an identity prior.
    """

    details "The binary", ~S"""
    One native Godot binary per platform out of `entities-godot-sandbox`,
    Vulkan everywhere, two heads. `modules/ggml` is `turboquant-godot`'s
    `modules/llm` moved under the RFD 2230 name with its ggml taken from the
    manifest at `weftspun-consolidated`, Vulkan only, the device chosen by
    name with no fallback to index 0 and none to the CPU. `modules/
    motionbricks` is stage A: the motion-bricks sources compiled against that
    module, byte-equal frames against the CMake build as the gate. Under RFD
    2229, stage A is the interim and the oracle: when RFD 2230's sandboxed
    adapter reproduces its frames, stage A stays as the parity oracle only
    and RFD 2212 is retracted. `modules/taskweft` is RFD 2205's shim over the
    standalone planner headers; `modules/game` holds the atelier scenes and
    the body host in-process; the sandbox pins advance to an upstream that
    carries SafeGDScript. The placed Godot 4.5 build stays the corpus scorer
    of record until a fixed 500-row sample per engine-bound family re-scores
    identically on the fork. The Lean compiler, the Elixir writer, mjlab,
    the ANNY line server, udon2godot and the dress-on pipeline stay outside.
    """

    details "Licences", ~S"""
    | source or tool | licence | evidence |
    | --- | --- | --- |
    | second-hand fashion set v3 | CC-BY-4.0 | DOI 10.5281/zenodo.13788681, `CITATION.cff` on the Hub |
    | STARFORGED-STD-3001 appendix E | CC-BY-4.0 | `CITATION.cff` on the Hub |
    | anny-dress-on-stage-train | CC-BY-4.0 | `CITATION.cff` uploaded 2026-09-08 |
    | Speaking_Faces | CC-BY-4.0 (data), MIT (code) | the project page; `IS2AI/SpeakingFaces` LICENSE |
    | constraint-twist sample | MIT | its `LICENSE.md`; the citation file is written but its remote refuses the push |
    | udon2godot | BSD-2-Clause | `CITATION.cff` at `ca8c62bc` |
    | ggml | MIT | `CITATION.cff` on `weftspun-consolidated` |
    | godot-sandbox, libriscv | BSD-3-Clause | `CITATION.cff` at `06a749b0` |
    | motion-bricks.cpp | Apache-2.0 | its LICENSE |
    | MotionBricks G1 GGML bundle | to read on the Hub page | cited from the teacher's `CITATION.cff` |
    | the matting model | pinned revision | recorded per matte |
    | VoxHammer, TRELLIS.2 | MIT | their LICENSE files |
    | rf-detr-cpp, voxhammer.cpp, nx-ggml | no licence file | stay out of any redistributed binary until fixed |
    """

    details "Every artefact lives in the parquet, in its modality's format", ~S"""
    Operator, 2026-09-08, reading a published row: "Make sure all the data is in
    parquet. I can't seem to find the source text of
    `rows/udon_scale_add/1/rank3.fbd`... this is a problem for the entire
    training datasets if we don't have that corpus data and it gets discarded.
    This is a problem for all the modalities and the i/o of the editscore data."

    The defect was real and complete. The writer kept each candidate's diagram
    under `rows/` and stored the *path* in `fbd_text`; the publisher uploads
    with `rows/` ignored and deletes any `rows/` already on the Hub. Every one
    of the eight published corpora therefore carried scores for diagrams it did
    not contain. A reader could see that rank3 compiled and missed the effect,
    and could not see the diagram that did it.

    The rule, stated once: **a row's artefacts are columns, not paths.** A
    candidate carries `fbd_text` and `fbd_xml` verbatim, `plan_json` and
    `result_json` where the family has a runner, `fbd_sha` over the text it was
    built from, and `fbd_path` only as provenance. The root row carries its
    traces as JSON strings, so the input half of an EditScore row is in the
    table with the output half. An artefact a family does not produce is an
    empty string; ETNF forbids the null.

    The formats, per modality (operator, same day): **CineForm** for image or
    audio data, because alignment across streams is the problem it exists to
    solve; **OpenUSD** for mesh data; any tensor format for latents; ZStandard
    parquet for the tabular carrier, as before.

    And the reader has to be able to look: a bare binary column shows the
    dataset viewer a byte count. A media column is a struct of `bytes` and
    `path`, and the card's `dataset_info` declares the feature; together those
    two make the viewer render a picture as a picture.
    """

    details "The green-screen keyer is not the matting model", ~S"""
    The operator asked whether a green-screen keying tool could replace the
    matting model for the dress-on garments, noting it may be used for
    dataset generation but not resold as a hosted service. It is now a
    blocklist row, and `BLOCKLIST.md` carries the argument under that row's
    subject. Two findings, and the first settles it on its own.

    **It is not a substitute.** The tool takes two inputs: a green or blue
    screen plate, and a coarse alpha hint that something else produced. It
    unmixes the screen colour out of edge pixels, which is a different task
    from isolating a subject on an arbitrary background. The garment
    photographs in the fashion set are studio and marketplace product shots,
    not screen plates, so the tool has nothing to unmix; its own repository
    ships a wrapper around the matting model as one of its optional hint
    generators, which places it downstream rather than in place.

    **The licence conflicts with publishing.** It is CC BY-NC-SA 4.0 with
    additional terms: non-commercial, share-alike, no repackaging or resale,
    no paid inference service, and a separate written agreement for
    commercial software integration. The operator's reading of the resale
    term is right, but the workspace's rules bind tighter than the licence.
    The blocklist already refuses CC-BY-SA for share-alike exposure, and the
    generator row refuses a licence whose use restrictions propagate into
    anything trained on the output while exempting passthrough use. A matte
    that ships inside a CC-BY-4.0 corpus is generator use, not passthrough.
    The install path is also `uv`, which the blocklist refuses for project
    environments.

    Where it would be admissible: a passthrough pass over screen-plate
    footage whose derived mattes are never published, which the tool's own
    terms permit and the row leaves alone. No such footage is in the
    workspace. The matting model at a pinned revision stays the dress-on hint
    generator, with the model name, revision sha and input photo sha recorded
    per matte.
    """

    details "Measurements", ~S"""
    | family | s/row at 5,000 rows, 8 workers | hours to 100,000 |
    | --- | --- | --- |
    | fbd (Os) | 0.161 | 4.5 |
    | compose | 0.152 | retired into Body |
    | trainer | 0.200 | 5.6 |
    | godot (Engine) | 0.228 | 6.3 |
    | harness (Blocks) | 0.284 | 7.9 |
    | plan | 0.286 | 7.9 |
    | react | 0.286 | retired into Body |
    | udon | 0.653 | 18.1, last, after a served translator |

    The five new traits are estimated from the nearest sibling and measured
    on a 500-row smoke before any long run; DressEdit runs 897 s per target
    on the 4090, 96 targets per day. A 5 mm stature tolerance is about three
    stacked pennies; 1 mm on a box corner is a credit card and a third; the
    spring hold threshold of 0.1 mm per tick is a sheet of paper.
    """

    details "Item 4 dropped, items 1 and 2 parked, FBD is the critical path", ~S"""
    Operator, 2026-09-08, in three steps. First the cost: "this is too
    expensive ... we have to drop 4 (generate identity)". Then a reversal on
    being shown where the cost actually sat: "is there a way to make this
    cheaper I dont want to cut identity trait". The trait is CPU solves worth
    8 to 14 hours; the photo leg hanging off it was a 2.15 TB transfer.
    Then the final ruling: "I think we should drop the 4 generate-identity",
    and separately "can you park dress on, and generate identity mixins. We
    need to ladder our work and currently the critical path is through fbd ->
    generate pose. We should also park generate pose too."

    So: the `Identity` trait is dropped with its `sigs/identity/` allowlist and
    the silent-stills leg that existed to calibrate its head fit. `anny.sigs`
    survives reduced to the four methods `DressOn` calls: the appendix-E
    solve, `Anny.build`, `Measure.stature` and `Measure.mass`. So the ANNY line
    server is still built. Items 1 and 2 park with their specifications intact;
    generate-pose is next off the ladder rather than cancelled, which is what
    "the critical path is through fbd -> generate pose" means.

    Two cost rulings stand with it. Rows land at 10,000 per trait before
    promotion to 100,000, and the promotion is free rather than a tenth extra
    because rows are allocated by seed range, so raising the quota appends
    instead of rewriting; the control is that 10,000 extended to 100,000 gives
    a first 10,000 byte-identical to a single 100,000-row run. And the photo
    set, if it ever returns, is read by byte range over a derived selection
    rather than downloaded whole: a zip's central directory sits at its tail
    and each member is independently deflated, so a seekable HTTP file lists a
    zip and fetches only the members wanted.
    """

    details "Segmenting the garment out of a VoxHammer edit does not work", ~S"""
    The operator asked for basic segmentation by mesh and image operations, so
    the original body could be reused under a new dress-on. Measured on
    `female-p1__g0` and reported rather than worked around, because the answer
    is no.

    Vertex colour cannot classify: the far-from-body, near-body, in-box and
    out-of-box groups all sit between 0.542 and 0.601 grey, so there is no
    albedo to separate cloth from skin.

    The dressed and undressed decodes differ everywhere, not at the garment:
    137,106 vertices against 95,482, 59 per cent of the dressed mesh's
    vertices more than 10 units-mm from the undressed decode's nearest vertex,
    and that far set spread through the leg and head bands rather than
    concentrated in the torso boxes. 58 per cent of it falls inside a box, and
    72 per cent of the in-box set is far.

    The decode does not conserve the body. In one shared unit-height frame,
    `body.usda` measures 0.0388 cubic metres, about 38 kg at water density and
    plausible for a 1.4 m first-percentile female; the undressed decode is
    0.0143 and the dressed one 0.0247. The dressed mesh exceeds the undressed
    by roughly 10 litres, and no garment is 10 litres of cloth. So the
    difference between the two decodes is dominated by what TRELLIS did, not
    by the garment, and any distance threshold on it measures the decoder.

    What works instead needs no model and no new capture. The garment's extent
    is already known by construction in the conditioning views: `composite.json`
    records the paste (`placed_at`, `size`, `rotation_deg`, `scale`,
    `alpha_threshold`, `torso_coverage`, `fraction_inside_body_mask`) and
    `view.json` records the camera that saw it (`frame`, `index`,
    `camera_position`, `forward_dot`, `mask_bbox`), and the garment alpha is an
    input we hold. Back-projecting that known region onto the body surface
    labels the cloth without inferring anything. This also answers the
    structured-light suggestion: a projected pattern buys correspondence, and
    here correspondence is already exact because the camera and the paste are
    ours. Structured light is the right tool for a capture rig with no
    geometry, not for a render we authored.

    The reusable direction is stronger than the one asked for: the original
    body was never destroyed. `body.usda` is exact, per-row, and regenerable
    from `identity.json`, so the open work is the garment as a shell over the
    body surface, which transfers to another body.
    """

    details "The order of work, as a ladder", ~S"""
    Each rung is finished and measured before the next starts, which is what
    laddering buys: a defect costs one rung rather than a milestone. The
    critical path is FBD, and generate-pose is what it runs to.

    **Rung 0, land and park.** The corrected dress-on corpus published, the RFD
    amendments and the logbook entry written, then a stop on items 1, 2 and the
    audio leg. Done.

    **Rung 1, the Elixir port and parity.** The order and the parity gate are in
    RFD 2236. Nothing new is written until the teacher's Python is Elixir.

    **Rung 2, the compiler's second half.** The codebooks, `Mutation.lean`, the
    `const` and `codebook` declarations, multi-output declarations, typed
    literal checks, the `ABS` block, and the compiler's `batch` mode, which
    drops the per-row cost. Rung 1's first half already landed:
    `export-tables` over 313 signatures in 13 tables, `--sigs`, `# index-only:`
    and `# uncovered:`, with four controls green.

    **Rung 3, distinctness at 5,000.** Today's duplicate rate reported on the
    eight Python stages, then every numeric widened into a codebook for the six
    carry-over families, and `distinct_rank1` equal to rows on every stage. The
    holdout declaration and the cross-trait leak pass land here, before volume
    rather than after it.

    **Rung 4, the six FBD families at 10,000 rows.** About an hour each at the
    measured rates, and the promotion control proves the seed-range allocator
    appends rather than rewrites.

    **Rung 5, promotion to 100,000**, cheapest first, each after its 500-row
    smoke and the operator's go on the measured hours. Udon last, and only once
    a served translator or a per-method cache brings it under 0.3 s per row from
    the measured 0.653.

    **Rung 6, the binary**, with the corpus re-scored on it per the 500-row
    parity samples.

    Then the ladder hands off to generate-pose: the `Body` and `Spring` traits
    unpark with their specifications intact, followed by dress-on and the audio
    leg of RFD 2241. Every rung ends the same way, with the citation check, the
    payload gate, and a logbook line carrying what was measured.
    """

    details "The deferred rulings, three of them retired by looking", ~S"""
    The plan carried about twenty questions marked for the operator to rule on, each
    scheduled to surface at the moment it blocked a rung. That shape spends an
    operator turn per question and spends them at the worst time, mid-rung. Measured
    2026-09-09, three of them were not questions at all.

    **Which godot-sandbox revision carries SafeGDScript.** Upstream v0.58, published
    2026-09-07, carries 71 paths naming SafeGDScript or `.sgd`. The plan named v0.54
    as the first and left the revision open. It is a pin advance rather than a
    ruling. What remains open is narrower and worth keeping: who redoes the six
    in-tree conversion commits against it.

    **Where `entities-godot-cineform` lives and how it is placed.** It does not
    exist, in either organisation, and it is not needed: `modules/cineform` is
    already in the fork on `feat/module-cineform` and rides into the assembly with
    the other twenty branches. The question assumed a repository that was never
    created and whose function is in-tree.

    **Whether `transport-taskweft-acp` must be unarchived for rung 3.** No. The
    concern was that widening the `Plan` family to 100,000 distinct rows means
    writing seeded domain variants into `priv/domains/*.ex` inside an archived
    repository, with three ways out, all of them costly. But
    `mix taskweft_acp.plan_sgd` resolves its domain as
    `Keyword.get(opts, :domain)` and then `File.read!` on that path, so the path is
    arbitrary. Generated variants live in the teacher repository and are passed in.
    The archived repository stays read-only and is read, which is what an archive
    permits. Neither unarchiving, nor moving the planner, nor dropping `Plan` is
    required.

    **What is left, and when it is actually needed.** Batched by the rung that wants
    it rather than discovered when it blocks:

    - Rung 1, the Elixir port: nothing.
    - Rung 2, the compiler's second half: the codebook defaults, which is one line.
      Three stages of eight levels giving 512 codes per real quantity, with the range
      declared per quantity; `[40]` for TIME on the 125 ms grid; INT ranges as one
      stage. A different ruling is a one-line change and the proofs are unaffected.
    - Rung 3, distinctness: nothing, now that the archived-repository question is
      answered.
    - Rung 5, promotion: one go per trait on the measured hours, which is the point
      of the gate and not a question to retire.
    - Rung 6, the binary: the llama.cpp pairing, accepting stage A as an interim
      oracle, how the teacher weights are distributed, the G1-to-VRM retarget path,
      the policy for a machine with only an integrated GPU, and who redoes the
      sandbox conversion commits.

    So the ladder needs **one ruling before rung 5**, and the rest cluster where the
    binary is built. An operator can leave the ladder alone from here to rung 4.
    """

    details "The deferred rulings, asked in one sitting and answered", ~S"""
    Operator, 2026-09-09: "please ask me all the open questions first". Seventeen were
    put in four rounds rather than surfacing one per rung, which is what the batching
    above was for. The answers follow, including the four that went against the
    recommendation and the two that rejected the question.

    **Two questions were refused as questions.** On sizing the codebooks: "you know you
    can size the codebook yourself right?" So the levels are derived from the numeric
    ranges the corpora already carry and from the distinctness rung 3 needs, and no
    operator turn is spent on it. On `obs_dim` and `K_max`: "ladder up. be honest" and
    "ladder up. I don't know what real vrms can use and they can abuse it". So neither
    is padded to a doctrine figure. The width starts at what the environment actually
    emits, with the manifest naming which slots are live, and grows when a term is
    added. `K_max` starts at the 22 chains measured on the sample and an avatar
    carrying more is **refused rather than silently truncated**, because truncation is
    how an abusive input becomes a wrong reward instead of an error.

    **The binary.** Stage A is accepted as an interim and as the parity oracle, and
    the ggml dependencies are ported into a Godot engine C++ module rather than left
    beside it. `llama.cpp` is not pinned at the old sync marker: `weftspun-consolidated`
    rebases onto the September ggml, which brings the vision path and obliges
    re-checking every consumer RFD 2188 consolidated. The teacher's 3.35 GB bundle is
    fetched through the RFD 2214 channel rather than shipped. The ACP door folds in,
    serving from the Godot binary over `modules/http3` and `modules/taskweft`, so the
    planner shim must reach parity with the NIF before that lands. The engine builds at
    **double** precision, which retires the single-precision assumption and means every
    timing on this desk was taken at the wrong precision and is re-measured.

    **A machine with only an integrated GPU runs on it** rather than refusing. That is
    still Vulkan, so the CPU-execution row is not touched, but the thing that row exists
    to prevent is a slow path nobody notices: the resolved device is printed at every
    load and its throughput recorded, so an integrated run is visible rather than
    silent.

    **The sandbox pin advances to v0.58** and the six in-tree conversion commits are
    redone against it, which is what unblocks the FBD guests, the export guests and the
    RFD 2213 VRM ELF. `voxhammer.cpp` becomes a repository under `v-sekai-fabric` and
    is placed in the manifest; it ships no licence file today and that is fixed before
    it goes anywhere. The G1-to-VRM retarget goes through `skin-tokens-cpp`'s ABI once
    its ggml pin is reconciled, which the rebase above already touches.

    **ANNY is ported, not wrapped.** The recommendation was a thin Python server under
    the runner rule; the ruling was "port the rig to elixir too. Find a nx accelerator
    and not too slow." So the appendix-E solve and the mesh build become Nx with an
    accelerated backend, and the acceptance is a measurement rather than a promise:
    the ported solve matches the shipped tools within the tolerances DressOn already
    asserts, and its wall time is recorded against the float64 CPU baseline.

    **Everything fetched is a data source.** The recommendation was that weights,
    tokenizers and constructed fixture inputs sit outside the ReBAC list; the ruling is
    that they do not. So the constraint-twist sample, the sandbox's `udon` set, every
    checkpoint and every tokenizer join the trusted list before anything reads them.

    That ruling meets the next one, and the consequence is recorded rather than left
    implicit: **`trust.exs` is the authority**, not Bao KV. The narrow
    `relationships/*` read is not granted, so the KV tuples stop being the replica the
    file derives from, and the anti-entropy pair between them is dropped rather than
    reported as passing. RFD 2200's tuple shape stays as the record of how the list is
    expressed elsewhere; here the file is what gates a fetch, and it is reviewed as a
    diff like any other tracked list.

    **Execution.** The nine remaining ports run to the end of rung 1 without stopping,
    each closed by its own parity gate, with one report at the end. `DressEdit` stays a
    GPU-budgeted anchor of 96 targets rather than a 100,000-row trait, and the
    republished corpora are a new generation carrying `:rand` and `-v2` cards rather
    than a Mersenne Twister port bought for byte parity.
    """

    details "What this RFD does not decide", ~S"""
    The llama.cpp pairing with the canonical ggml; the godot-sandbox
    revision to advance to and who redoes the six conversion commits; where
    `entities-godot-cineform` lives; whether the teacher weights ship with
    the game; the G1-to-VRM retarget path; the policy on a machine with only
    an integrated GPU; whether `voxhammer.cpp` is placed or removed; the
    obs_dim, K_max and ROM rulings of RFD 2238; the likeness and consent RFD;
    whether the Elixir door joins the monolith. Each is ruled before its
    integration step.
    """

    drafted_by :ai
  end
end
