# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2236. `mix rfd.render` renders rfd/2236-fbd-teacher-in-three-steps/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2236 do
  use RFD.DSL

  rfd 2236, "A teacher that exports Function Block Diagrams, gained in three steps" do
    state :discussion

    feature "the model behind `/fbd` on the taskweft-acp door: a constructed EditScore-shaped corpus, continued pretraining of Gemma 4 E2B under QAT, then reinforcement training with the compiler and the sandbox as the hard half of the reward"

    scope "`3-interactor/taskweft-fbd-teacher`, `3-interactor/taskweft-fbd-compiler`"

    decision ~S"""
    The teacher's only output is an IEC 61131-3 Function Block Diagram in the
    PLCopen subset `taskweft-fbd-compiler` parses; a llama.cpp grammar makes any
    other output unsampleable. The model is gained in three gated steps rather
    than taken from a stock checkpoint: a constructed corpus whose labels the
    compiler and a runner set (step 1, shipped), continued pretraining of Gemma
    4 E2B on its rank1 rows with the forward pass seeing the 4-bit noise (step
    2), and reinforcement training whose reward is compile, run and effect from
    the compiler plus a frozen judge (step 3). The teacher runs on an executor
    side with the GPU, never on the hosted door. `DETAILS.md` carries the rest.
    """

    problem ~S"""
    The operator ranked four candidate efforts and picked this one: an MCP-ACP
    server whose teacher language model is forced to export a Function Block
    Diagram, with the Godot engine as the scripting engine that touches the
    operating system. A stock model behind a grammar produces well-formed
    diagrams that mean the wrong thing; nothing in the workspace measured how
    often. The compiler existed as a marker-counting skeleton, the sandbox host
    existed for exported sessions, and no corpus tied an intent to a diagram.
    """

    references ~S"""
    - RFD 2229, interchangeable parts, which decides what each leg reuses
    - RFD 2152, RFD 2154, RFD 2155, RFD 2156 and RFD 2157, the PLCopen, sandbox and compiler line this continues
    - RFD 2167, the reward-distillation shape step 3 follows
    - RFD 2234, whose writer set the frozen-judge doctrine and the three-parquet corpus shape
    """

    related ~S"""
    RFD 2235 (the door and its executors), RFD 2188 (one ggml across the workspace), RFD 2196 (dataset viewer rules the publisher follows).
    """

    details_title "A teacher that exports Function Block Diagrams, gained in three steps"

    details "Interchangeable parts", ~S"""
    | leg | the part that already exists | what changes |
    | --- | --- | --- |
    | the door, executors, session log | `transport-taskweft-acp` | `/fbd`, one executor capability, one `acp/fbd` event |
    | the model runtime | `turboquant-godot/thirdparty/llama_cpp` (RFD 2188), `llama-server` with the GBNF `grammar` field | a CUDA build on the desk |
    | the loopback server client | `qwen35-defiant/src/interactor.{h,cpp}` | an Elixir twin |
    | the FBD compiler | `taskweft-fbd-compiler` (Lean) | a real parser, the stage 1 lowering, a CLI |
    | the runtime host | `taskweft-godot-sandbox` and the host scene in `transport-taskweft-acp/priv/godot_project` | the guest is a compiled diagram rather than an exported session |
    | the dataset shape | `anny-render-corpus/maskscore_rung_1_*` (root, candidates, scores; controls before the emit) | one new stub row for the FBD task |
    | the judge | `editscore` and the frozen-judge doctrine | a text-and-trace prompt |
    | the training pattern | `tropes-removal-model/train_rewriter.py`, RFD 2167 | the same shapes on Gemma 4 E2B |
    | the publish recipe | `publish_artifacts.py` | a new dataset repository |

    No new dependency mechanism, no second model runtime, no second sandbox, no
    hosted-API generator, no post-training quantization.
    """

    details "The compiler after this RFD", ~S"""
    `Parser.lean` reads a program POU with BOOL, INT and STRING locals,
    `inVariable` literals, blocks wired through `connectionPointIn`, and
    `outVariable`s; an element outside that subset is refused by name, and the
    tag-soup fixture is the control. `Sgd.lean` lowers `WRITE_FILE`, `RUN` and
    `READ_FILE` in EN/ENO order, or localId order, to the four-call SafeGDScript
    guest the host scene already drives (`steps`, `step`, `record`, `pending`,
    RFD 2156) and to a JSON plan for any other runner; every other block is
    counted as skipped, never dropped. `Main.lean` gains `check`, `emit` and
    `plan`. The ELF emit of RFD 2157 stays the next stage; the toolchain file
    pins Lean 4.34.0-rc1 while the desk builds it on 4.30.0.
    """

    details "Step 1: the corpus", ~S"""
    Constructed, so ordinary training data under CLAUDE.md. Four templates over
    operating-system chores (write a file; write then check it exists; run a
    command that prints a number; create files then count them) turn a seed
    into an intent, the reference diagram (rank1), a diagram that compiles and
    does the wrong thing (rank3: a wrong literal, a missing file, one file
    short) and one the compiler refuses (rank5: an unwired pin, an EN/ENO
    cycle, an unknown block). The stub row is
    `("fbd", "intent_to_fbd", "instruction_following", "input_intent", "text")`.

    Scores come from `check` and `plan` (parses, compiles) and from a runner
    that performs the plan's steps in a scratch directory the way the host
    scene does (runs, steps, effect_matches, wall_ms, refusal). Three controls
    are asserted on every row before the emit: rank1 compiles, runs and
    matches; rank3 compiles and misses; rank5 is refused. The writer's own
    negative control hands rank5's verdict to rank1 and must refuse the emit.
    One row in ten is a holdout written apart. Three ZStandard parquets in
    ETNF plus the joined view; the publisher follows RFD 2196's `configs`
    block.
    """

    details "Step 1 as it stands: eight families at 5,000 rows", ~S"""
    Every family keeps the shape above: one intent, three candidates, the three
    controls asserted on every row before the emit, and three splits. Measured
    on this desk with eight workers; the seconds per row are what a 100,000-row
    run is projected from.

    | family | published as | rows | train | test | evaluation | templates | s/row | compiler |
    | --- | --- | --- | --- | --- | --- | --- | --- | --- |
    | fbd | `chibifire/taskweft-fbd-editscore-train` | 5,000 | 3,375 | 375 | 1,250 | 4 | 0.161 | `d3279ec` |
    | react | `chibifire/taskweft-fbd-react-train` | 5,000 | 3,600 | 400 | 1,000 | 5 | 0.286 | `d3279ec` |
    | harness | `chibifire/taskweft-fbd-harness-train` | 5,000 | 4,059 | 451 | 490 | 69 | 0.284 | `72c2603` |
    | compose | `chibifire/taskweft-fbd-compose-train` | 5,000 | 3,600 | 400 | 1,000 | 5 | 0.152 | `ed1ac1d` |
    | plan | `chibifire/taskweft-fbd-plan-train` | 5,000 | 4,050 | 450 | 500 | 10 | 0.286 | `d3279ec` |
    | godot | `chibifire/taskweft-fbd-godot-train` | 5,000 | 3,897 | 433 | 670 | 15 | 0.286 | `7d34ff4` |
    | trainer | `chibifire/taskweft-fbd-trainer-train` | 5,000 | 3,807 | 423 | 770 | 13 | 0.103 | `7d34ff4` |
    | udon | `chibifire/taskweft-fbd-udon-train` | 5,000 | 3,681 | 409 | 910 | 11 | 0.569 | `7d34ff4` |

    The Udon family's census: 3,681 training rows over 9 templates, 12 block
    kinds present, 27 frames, 105.2 tokens on average and 140 at most, with
    `udon_min_max` and the `LIMIT` block held out to evaluation and absent from
    training. The godot, trainer and udon stages were regenerated under one
    committed compiler and a recorded engine (`4.5.stable.official.876b29033`,
    sha256 `7b77f373...`); the five before them carry the compiler sha their run
    used. The manifest records the compiler and the engine by name and hash
    only: an absolute path in a manifest names the desk and its user, and the
    publisher refuses one.

    Under RFD 2239 these become traits at 100,000 rows, react and compose
    retiring into a Body trait, and `mix fbd.rfd_tables` writes this table from
    the stage manifests rather than by hand.
    """

    details "Steps 2 and 3, the gates", ~S"""
    Step 2 continues pretraining `google/gemma-4-E2B-it-qat-q4_0-unquantized`
    on rank1 rows on the desk's 4090, the grammar as a filter on anything that
    enters, quantization-aware throughout (no adapter over a quantized base, no
    quantize-after). Gate: on the holdout, the fraction of completions that
    compile, run and match, with the stock checkpoint under the grammar as the
    floor row.

    Step 3 is GRPO over that checkpoint. The hard half of the reward is the
    compiler and the runner (parses, compiles, runs, effect, summed); the soft
    half is EditScore on intent, diagram and trace with its tuple frozen
    before the run and recorded on every row, a refusal never a score.
    Sampling stays under the grammar. Gate: the same holdout table, three rows
    (stock, pretrained, reinforced); the reinforced row must beat the
    pretrained on effect without losing compile rate, or it does not ship.
    The shipped checkpoint is what `mix taskweft_acp.executor --teacher`
    serves.
    """

    details "The text form and the reverse edit", ~S"""
    A diagram now arrives in three forms told apart by extension: the PLCopen
    XML the corpus stores, a text form with one line per block, literals
    inline and wires by name (`b5 = READ_FILE(EN=b3.ENO, PATH="out.txt")`),
    and a SafeGDScript guest lifted back into blocks, each PLAN entry the
    block its kind names with EN chained to the step before and the header's
    not-lowered blocks kept. The text reader numbers localIds in order of
    appearance, so text to XML to text is a fixed point and the XML printer
    reproduces the fixture byte for byte; `fbd_text.gbnf` in the door repo
    admits the same subset. The teacher samples the text form and the XML is
    derived, because of the table below; the operator's reverse edit (a
    diagram edited as GDScript lifts back, one edited as text emits GDScript)
    holds through one POU.

    Gemma 4's tokenizer over every rank1 candidate of the train split, the
    three round trips asserted on each (text to XML to text a fixed point;
    the plan from the text, the XML and the lifted guest identical):

    | form                 | rows  | tokens mean | tokens p50 | tokens max | chars mean |
    | -------------------- | ----- | ----------- | ---------- | ---------- | ---------- |
    | PLCopen XML          | 4,500 | 444.4       | 354.5      | 1,086      | 1,696      |
    | text form            | 4,500 | 70.7        | 55.0       | 183        | 165        |
    | SafeGDScript guest   | 4,500 | 314.0       | 287.5      | 509        | 895        |

    4,500 of 4,500 round trips held; the text form costs 6.29 times fewer
    tokens than the XML and 4.4 times fewer than the guest. Controls refused
    by name: an unwired pin, an unknown block, an unknown step kind.
    """

    details "The surfaces the teacher speaks", ~S"""
    The operator's direction (2026-09-08): train the teacher on the engine as
    the sandbox exposes it, and on any surface brought in the way the
    microduck trainer's is. The workspace already keeps those surfaces as
    signature tables under the compiler's `sigs/` (one line per entry,
    `Class.method(args) -> Ret`); the teacher's only output is a diagram, so
    an API call is a block. `CALL[Class.method](TARGET=..., arg=...)` names a
    signature in its bracket; its pins are `TARGET` (a node path, a singleton,
    the tree, a builtin literal, or the `RET` of an earlier CALL) and the
    signature's arguments; its outputs are `RET` and `ENO`. The compiler loads
    every table (`TASKWEFT_SIGS_DIR`, else `sigs/` beside it), refuses an
    unknown signature or an unwired argument at `check`, lowers each CALL to a
    `call` step (`command`, `path`, `args` in table order, an earlier RET as
    `#<id>.RET`), and lifts the step back by that id; text, XML and guest are
    a fixed point on the API fixture, and the two controls are refused by
    name. `sigs/mjlab_trainer.sigs` is the trainer surface at rung 0 (38
    entries: reward, observation, termination and event terms, the action and
    command configs, the microduck actuator fields).

    The Godot family scores a row by what the engine did. `api_fixture.tscn`
    (in `taskweft-godot-sandbox`) holds one node of every class the rung-0
    engine table names and the resources a call hands between them;
    `api_runner.gd` instantiates it, performs each call step deferred on the
    first frame (a node added during the tree's `_initialize` is not yet
    inside the running tree, so a Timer will not start there), and writes
    every return back. Fifteen templates (a position set and read, a
    transform, the generic property setter, label and button text, a 2D node,
    a rigid body's mass, a timer started and stopped, vector and transform
    arithmetic, builtin values, resources handed between nodes, tree
    operations, introspection, the loader, camera and input) cover 52 of the
    table's 60 entries; rank3 carries a wrong argument, rank5 a signature
    outside the table. Eight entries are named uncovered rather than sampled
    around: `Object.connect` (a Callable has no literal form), `RefCounted.
    unreference` (it frees its target), the five virtual callbacks (what a
    guest implements, not what a plan calls), and `OS.get_ticks_msec`, which
    Godot 4 does not have; that last one is a defect in the rung-0 index the
    anti-entropy pass should carry to the generated header.

    A Godot row's block column holds its signatures, so the census enumerates
    the surface and `--holdout-blocks <signature>` is the signature holdout
    axis beside the family axis; the first corpus holds out the 2D-node family
    and `Camera3D.unproject_position`, both to the evaluation split.

    The trainer family writes configuration programs over
    `sigs/mjlab_trainer.sigs`, one CALL per term, and scores them by the
    configuration mjlab would run: `trainer_cfg_runner.py` (in
    `mjlab_motionbricks`, served from WSL one JSON line per plan) applies the
    calls to a fresh task config and reads the term table back from the
    config objects (reward weights and parameters, observation noise,
    metrics, terminations, the action and command configs, the sim rate, the
    scene, the events, the PD actuators). Thirteen templates cover 36 of 38
    entries; the BAM and backlash actuator models are named uncovered because
    the environment has no actuator class for them. A non-number, an unknown
    term and an inverted command range are refused by the runner and are its
    self-test controls.

    The Udon family is the direction udon2godot does not go. A seeded
    UdonSharp method (eleven shapes: scaling, blending, clamping, selection,
    band tests, branches that assign, boolean logic, min and max, weighted
    mixes) is written as C#, translated with the pinned udon2godot in WSL,
    and lifted by `gd_lift.py` into a scan controller: one input per
    parameter, `ret` for the return, a block per operation, a `SEL` per
    variable a branch assigns, a computed local emitted once and read by
    wire. Everything outside that subset is refused by reason (loops,
    member access, arrays, strings, `abs`, conversions, void methods,
    returns inside branches). The reference is Godot itself: `udon_runner.gd`
    runs the translated class on the row's traces through the udon runtime
    addon, and the diagram's simulation must match it tick for tick; rank3
    is the first mutation the traces can tell apart, rank5 reads an input
    the program never declared. The intent is the C# source. The fixture
    methods udon2godot ships are counted by the same lift: none of them lifts
    today (void test harnesses, `Array` and `Vector3` signatures, `absf`),
    and an `ABS` block is the first addition that would admit real ones. The
    lift lives in the teacher's tools rather than the Lean compiler for now;
    the compiler checks and simulates its output, which is what the
    measurement rests on.
    """

    details "What was measured", ~S"""
    The compiler builds on Lean 4.30.0 in 12 jobs; `check` accepts the
    reference diagram (2 blocks, 2 operating-system, 1 variable, 3 literals),
    `plan` lowers it to two steps, and `check` refuses the tag-soup control
    with "<note> is not part of the FBD subset". The writer wrote 8 rows in
    2.2 seconds on this desk with every control holding, and its negative
    control refused the emit with "identity control failed".

    The corpus was written twice. The first pass assigned templates by row
    index modulo four and held out every tenth seed, so the holdout carried
    only the two one-step templates; templates now cycle every ten seeds and
    the second pass is what shipped, 5,000 rows in 282 seconds at 8 workers
    against compiler `083f3c3`, 1,250 rows per template, 4,500 train and 500
    holdout with 125 of each template in the holdout, no nulls in any of the
    eight ZStandard parquets, published as
    `chibifire/taskweft-fbd-editscore-train`. The scores the compiler and
    the runner set, as means over the 4,500 train rows (the holdout's are
    within 0.01 of every cell):

    | candidate | parses | compiles | runs | effect | steps | refused |
    | --------- | ------ | -------- | ---- | ------ | ----- | ------- |
    | rank1     | 1.00   | 1.00     | 1.00 | 1.00   | 1.88  | 0       |
    | rank3     | 1.00   | 1.00     | 0.75 | 0.00   | 1.44  | 0       |
    | rank5     | 0.50   | 0.00     | 0.00 | 0.00   | 0.00  | 4,500   |

    rank3's runs column is the read-a-missing-file mutant stopping short on
    its second step; rank5's parses column is the unknown-block mutant,
    which the parser refuses, against the unwired-pin and cycle mutants,
    which parse and fail in the lowering. Every row's three controls held,
    so the table is the construction read back rather than a finding.
    """

    details "The corpus after the surfaces", ~S"""
    Every family below was written on this desk at 5,000 rows with the three
    controls asserted on each row, no nulls in any parquet, and the census's
    leak control refused; each is published under `chibifire/taskweft-fbd-
    <family>-train` with `train`, `test` and `evaluation` named in the viewer.
    `test` is every tenth seed; `evaluation` is the held-out families and
    block kinds (for the API families, held-out signatures), never trained
    or tuned on.

    | family | train | test | evaluation | held out | surface in train | wall |
    | --- | --- | --- | --- | --- | --- | --- |
    | fbd | 3,375 | 375 | 1,250 | `write_then_count` | 3 block kinds | 282 s |
    | react | 3,600 | 400 | 1,000 | `button_sequence_then_idle` | 5 block kinds | 1,432 s |
    | harness | 4,059 | 451 | 490 | TOF, RS, GE, MOD | 24 of 28 block kinds | 1,418 s |
    | compose | 3,600 | 400 | 1,000 | `walk_from_stick` + `tracker_lost_freezes` | 8 block kinds | 761 s |
    | plan | 4,050 | 450 | 500 | `session_reactions take_seat` | 7 block kinds | 1,431 s |
    | godot | 3,897 | 433 | 670 | 2D-node family, `Camera3D.unproject_position` | 44 of 52 signatures (8 uncovered by name) | 1,141 s |
    | trainer | 3,807 | 423 | 770 | `push` family, `Reward.self_collisions` | 28 of 36 signatures (2 uncovered by name) | 1,001 s |

    Two defects the runs caught, both in the harness family's rank3: a
    mutation that the three picked traces could not tell from the original
    (a `TOF` whose preset is wired from a product, a `LIMIT` whose bounds
    the perturbation had made equal), so rank3 is now the first candidate
    the traces distinguish, with spare traces swapped in and equal bounds
    kept apart; and a publisher that uploaded the writer's scratch tree
    (45,011 files) beside the parquets, now skipped and removed from the
    hub. The Udon family's 5,000-row run was in flight when this section
    was written; its smoke of 110 rows across the eleven shapes held every
    control, and the fixture census stands at 0 lifted of 63 methods with
    the reasons counted.
    """

    details "The Elixir port, in order, with parity as the gate", ~S"""
    Operator, 2026-09-08: port everything to Elixir first, and no new trait
    before the teacher's Python is Elixir. The order is Python size ascending,
    so a defect is found on a small file: `frames` at 64 lines,
    `compose_templates` at 85, `census` at 135, `plan_rows` at 156,
    `fbd_templates` at 180, `harness_templates` at 217, `react_templates` at
    218, `udon_templates` at 276, `trainer_api_templates` at 417,
    `write_fbd_rows` at 526, `godot_api_templates` at 566. `gd_lift` at 436
    goes last, immediately before the Udon rows, and is deleted together with
    `udon_templates.py`.

    **Parity is the gate before any Python file is deleted.** Re-scoring a
    family's existing `rows/` tree with the Elixir scorer under one committed
    compiler hash must give identical score rows. The parity table records each
    Python stage's original hash and the single reference hash. Rank1 hash
    equality for seeds 0 to 39 is required only for families with no seeded
    draws, because `:rand` cannot reproduce Python's Mersenne Twister; the
    Elixir corpora are a new generation with their own `rng` in the manifest
    and `-v2` cards, rather than a port of that generator for byte parity.

    Each family closes with its parity smoke and one logbook line of days
    spent, and the operator's go comes after the first three land.

    What does not get ported is named rather than left implicit. A surviving
    Python file is a runner wrapping a model and says so in its first line: the
    ANNY line server, the VoxHammer readback, the matting and render and judge
    model runtimes, the mjlab trainer runner, and the Hub upload call until the
    Req commit path is proven.
    """

    details "Staged row counts: 10,000 before 100,000, and why that is free", ~S"""
    Operator, 2026-09-08: every trait lands at 10,000 rows first and is promoted
    to 100,000 only after its census, duplicate gate and leak controls are clean
    on the smaller stage. A bad template then costs an hour to find instead of
    eight.

    **Staging is free rather than a tenth extra, and that is a constraint on the
    allocator rather than an assumption about it.** Rows are allocated by seed
    range per template, so a template's row for seed `s` does not depend on the
    quota; raising the quota appends and never rewrites, and `--resume` at the
    higher quota keeps the first 10,000 and writes only the remaining 90,000.

    The control: writing 10,000 and extending to 100,000 gives a first 10,000
    rows byte-identical to a single 100,000-row run of the same family under the
    same rng and compiler hash. If that control fails, staging costs the extra
    tenth, and the manifest says so rather than this document assuming it did
    not.

    Only the 100,000-row stage is published. The 10,000-row stage is a gate, and
    its manifest is kept beside the full one so the promotion is auditable.

    Measured cost at 5,000 rows on 8 workers, in seconds per row: fbd 0.161,
    compose 0.152, trainer 0.200, godot 0.228, harness 0.284, plan 0.286, react
    0.286, udon 0.653. Linear to 100,000 that is about 50 hours for the six
    families that carry over, of which udon is 18. New traits are estimated from
    the nearest sibling and measured on a 500-row smoke before any long run.

    The staging is also the budget lever between this work and the audio leg of
    RFD 2241. Every trait at 10,000 is about 8 to 9 hours across all of them;
    the promotions are the other 72 to 81. Because a promotion appends,
    deferring every promotion until after that leg lands costs time-to-100,000
    and nothing else. Nothing is cut and nothing is redone.
    """

    details "The port order was by file size, and the import graph disagrees", ~S"""
    Corrected 2026-09-09 by doing the first port rather than by reading the list again.

    `frames` ported and passed its parity gate: every one of the nine templates at
    seeds 0 to 99, enumerated rather than sampled because the population is fixed and
    small, gives the frame index and the filled sentence the Python returned. 900
    cases, none differing, and two planted defects, one in a sentence and one in a
    frame index, both reported. The fixture and its control now live in the test
    suite, so the two answers stay pinned together.

    **It could not then be deleted, which is what exposed the ordering defect.**
    `fbd_templates.py` and `react_templates.py` both `from frames import pick`, and
    both are ported later. Parsing the twelve modules for their in-repo imports shows
    the same shape almost everywhere: **nine of the twelve carry a deletion blocker**,
    an importer scheduled after them.

    The order was also wrong in the other direction, which matters more because it
    blocks work rather than deferring a deletion. `react_templates` sits eighth by
    size and is imported by five modules scheduled before it, so
    `compose_templates`, `plan_rows` and `harness_templates` would each have been
    ported against a dependency that did not exist yet.

    The order is therefore a topological sort of the import graph, with file size as
    the tie-break so the original intent survives where the graph allows it:

        0  frames                 64      6  plan_rows             156
        1  census                135      7  harness_templates     217
        2  gd_lift               436      8  trainer_api_templates 417
        3  fbd_templates         180      9  godot_api_templates   566
        4  react_templates       218     10  udon_templates        276
        5  compose_templates      85     11  write_fbd_rows        556

    `gd_lift` moves nine places earlier, from last to third: it has no in-repo
    imports and `udon_templates` needs it. The plan had it last on the reasoning that
    it should be deleted immediately before the Udon rows, which confuses when a
    module is ported with when its Python is deleted.

    **So parity and deletion are separate events.** Parity closes a port and is the
    gate on trusting the Elixir; deletion waits until the last importer is ported and
    is the gate on removing the Python. Recording them as one step is what put
    `frames` first and made its deletion impossible at that position.
    """

    details "Function colours, and the one place this language drops the token", ~S"""
    Operator, 2026-09-09: study the debate under "Function Arguments Are Not
    Function Colors" against this compiler. The argument there is whether an
    effect is a property that propagates up a call stack, or an argument that
    does not. The strongest position in the thread is that Haskell's IO is
    honest precisely because its token is a real argument, threaded explicitly.

    **This language already took that side, and the pins show it.** Checked
    against rows in the published corpora rather than against the grammar.
    A pure block produces a value and nothing else:

        g = ADD(IN1=n, IN2=m, IN3=k, IN4=-2)
        v = g.OUT

    An effectful one produces a token, and a chain of them threads it:

        n = CALL[Node.get_node](TARGET="/root/Fixture", path="Body")
        s = CALL[Node3D.set_position](EN=n.ENO, TARGET=n.RET, position="...")
        g = CALL[Node3D.get_position](EN=s.ENO, TARGET=n.RET)
        done = g.ENO

    So the colour is a wire. `.RET` carries the value and `.ENO` carries the
    effect, on separate pins, which is stronger than a colour: `s` depends on
    `n`'s **value** through `TARGET=n.RET` and on `n`'s **effect** through
    `EN=n.ENO`, and those two dependencies are expressible apart. A colour
    cannot say that. There is also no call stack to propagate up: a program is
    one flat scan, so the half of the debate about intermediate functions
    having to be rewritten does not arise here at all.

    The `--sigs` allowlist is the other half. It bounds which tables a program
    may call, which restricts **downward**, the direction the thread identifies
    as sound (Rust's `const` discharges restrictions down the stack; `unsafe`
    propagates up). Rung 2's `uses <trait>` declaration is that restriction
    made explicit in the text.

    **Where the language is weaker than the Haskell it resembles: the token is
    optional.** `Netlist.build` reads `EN` as an `Option` and takes `none`
    without complaint, and nothing consults the signature table to ask whether
    a block is effectful. So an effectful `CALL` may be written with no `EN`,
    and two effectful blocks may sit in one program with no chain between them.
    Their order is then decided by `order`, which takes the first ready node in
    the list it was given, so it falls back to **source position**.

    That is deterministic, which is better than it could be, but it means the
    text carries meaning the graph does not: two programs with identical
    netlists and different line order can perform their effects in different
    orders. It also puts a hole in the mutation search, which decides a
    candidate is visible by simulating it: a mutation that reorders two
    unchained effects changes behaviour without changing the graph the
    simulator is asked about.

    The fix is one of two, and it is a language change rather than a bug fix,
    so it is recorded here and ruled on rather than taken: either require `EN`
    on any block whose signature is declared effectful, which makes the token
    mandatory as Haskell's is, or refuse a program that contains two unchained
    effectful blocks and name them. The first is a stronger guarantee and
    invalidates existing rows that omit `EN` on a first call; the second is
    narrower and leaves single-effect programs alone.
    """

    drafted_by :ai
  end
end
