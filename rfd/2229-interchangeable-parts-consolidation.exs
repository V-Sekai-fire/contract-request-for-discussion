# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2229. `mix rfd.render` renders rfd/2229-interchangeable-parts-consolidation/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2229 do
  use RFD.DSL

  rfd 2229, "interchangeable-parts consolidation as workspace policy" do
    compact_head true

    state :discussion

    flight_level :l3

    feature "codify the interchangeable-parts directive from
2026-09-05 as workspace policy plus name the concrete candidates
already visible in the goal manifest"

    scope "`weftspun-keypoint/default.xml` (goal manifest), all
future RFDs that add a new module / fork / build fragment /
loader path, memory `consolidate-interchangeable-parts`"

    decision ~S"""
    Operator directive 2026-09-05, verbatim: *"like ford's factories
    we have to conslidate our interchagable parts. we have too many
    parts"* + trademark-scrub follow-up *"please avoid using the
    company name ford as a trademark for inventing the interchable
    parts process"*.

    `DETAILS.md` carries the full text of this RFD.
    """

    related ~S"""
    - RFD 2188 (one ggml across workspace), the reference
      consolidation this RFD generalises.
    - RFD 2210 (L3 atelier shipping surface), the arc that
      produced the directive.
    - RFD 2211 (base tree entities-godot-sandbox), picked the tree
      the trim in `weftspun-keypoint#101` acted on.
    - Memory `consolidate-interchangeable-parts`, the operator
      directive + how-to-apply, kept as the working memory next to
      this policy.
    - Memory `coordinator-verify-before-relay`, records the earlier
      trademark violation this RFD's naming was scrubbed against.
    """

    details_title "interchangeable-parts consolidation as workspace policy"

    details "The policy", ~S"""
    Operator directive 2026-09-05, verbatim: *"like ford's factories
    we have to conslidate our interchagable parts. we have too many
    parts"* + trademark-scrub follow-up *"please avoid using the
    company name ford as a trademark for inventing the interchable
    parts process"*.

    **Historical note.** Interchangeable parts predate the company
    that got named in the first draft by a century, Whitney's musket
    contract 1798, the Springfield Armory / American System of
    manufactures through the 1820s–1850s. That company scaled
    assembly-line production using interchangeable parts; it did not
    invent them. Neutral vocabulary is **interchangeable parts**,
    **standardized interfaces**, **the American System of
    manufactures** if a historical anchor is wanted.

    **The workspace rule (goes into CLAUDE.md next):**

    Before landing a new part, a module, a fork, a build fragment,
    a loader path, a bundle format, a C API extension, check whether
    an existing part covers the interface. If yes, extend the
    existing part rather than land a parallel one. Every RFD that
    names a new component carries a sentence naming the existing
    part it substitutes for and why substituting doesn't work.
    "Doesn't work" is a measurement, not a preference.

    Two mechanisms already carry the rule for specific interfaces:

    - `2-contract/ggml/` (RFD 2188) as the single ggml source every
      consumer links.
    - `2-contract/manuals-weftspun/` (this repo) as the single
      workspace-doctrine mount, reached from `weftspun-keypoint` via
      linkfile.
    """

    details "Live candidates in the manifest (2026-09-05 as of writing)", ~S"""
    Enumerated from `weftspun-keypoint/default.xml` at 112 project
    entries.

    ### Three `ggml` checkouts

        3-interactor/trellis2cpp/ggml       remote=weftspun  rev=331b9cba
        3-interactor/ggml-seethrough        remote=weftspun  rev=3404c951
        2-contract/ggml                     remote=weftspun  rev=weftspun-consolidated

    **RFD 2188 named `2-contract/ggml` as the single ggml source
    workspace-wide.** The manifest still ships three checkouts. Two
    of them (`trellis2cpp/ggml`, `ggml-seethrough`) are consumers
    still pinned to their own ggml revisions rather than reading
    through the shared source.

    **Verification needed before trimming.** Whether each consumer
    has actually migrated to `2-contract/ggml`'s API, or whether the
    pinned revision holds something the consolidated source doesn't
    yet cover. A CI green on `trellis2-ex` and `seethrough` against
    `2-contract/ggml` is the measurement.

    Follow-up L1 RFDs (planned in the 22xx range): one per consumer
    scoping the migration + trim per project.

    ### `entities-godot-main` (trimmed 2026-09-05)

    Same repo as `entities-godot-sandbox` at revision `main` instead
    of `feat/vsk-sandbox-4.7`. Trimmed as `weftspun-keypoint#101`.
    Recorded here as the reference case that proves the pattern
    lands cleanly.

    ### `motion-bricks-cpp` + `kimodo` + `skin-tokens-cpp`

    Three ggml-graph-in-C++ shapes with three separate build
    systems. All target the same interface: a C API that Godot's
    `modules/motionbricks/` (RFD 2212) wraps for scene-graph access.
    Consolidation candidate: one `ggml-godot-module-kit` that all
    three link, replacing three per-project CMake `if(NATIVE_WEBGPU)`
    branches with one shared fragment.

    Not urgent; the three projects are early enough that their build
    systems haven't diverged much. RFD 2188 shared source + a small
    build-fragment consolidation covers most of it. Concrete work is
    a follow-up L2 once RFD 2212's `modules/motionbricks` lands.

    ### Manifests-of-manifests

    **Not a candidate.** `weftspun-keypoint` is the single live goal
    manifest per CLAUDE.md's "Sides" rule; the archived
    `weftspun-mesh-latents` is placement history, not a parallel
    manifest.
    """

    details "Verification", ~S"""
    The policy is measured by:

    1. **RFD-add gate.** A new RFD that adds a component but does
       not name an existing part it substitutes for is asking for a
       parallel part. Add a section to `check_rfd_structure.py`
       requiring an "Alternatives considered" or "Substitutes for"
       paragraph when the RFD's frontmatter is tagged as adding a
       module/fork/bundle-format. Draft in a follow-up PR; RFD 1000
       carries the structure list this gate reads from.
    2. **Manifest-scan gate.** `scripts/check_manifest_dupes.py`
       (new) reads the live goal manifest, groups by name/path/
       remote+rev, and reports groups of size > 1 as candidates
       needing a doctrine pointer (an RFD saying why both stay) or
       a trim PR (like `weftspun-keypoint#101`). Silent-skip case:
       the two-manifest state that exists during a manifest cutover
      , the gate reports both, doesn't fail on the presence.
    """

    details "Related", ~S"""
    - RFD 2188 (one ggml across workspace), the reference
      consolidation this RFD generalises.
    - RFD 2210 (L3 atelier shipping surface), the arc that
      produced the directive.
    - RFD 2211 (base tree entities-godot-sandbox), picked the tree
      the trim in `weftspun-keypoint#101` acted on.
    - Memory `consolidate-interchangeable-parts`, the operator
      directive + how-to-apply, kept as the working memory next to
      this policy.
    - Memory `coordinator-verify-before-relay`, records the earlier
      trademark violation this RFD's naming was scrubbed against.
    """

    details "Operator context 2026-09-05", ~S"""
    Two verbatim directives (paired):

    > like ford's factories we have to conslidate our interchagable
    > parts. we have too many parts

    > please avoid using the company name ford as a trademark for
    > inventing the interchable parts process

    Both applied. The first is the policy; the second is the naming.
    The RFD carries neutral vocabulary from here on.
    """

    details "A caller is a part, and the missing one cost whole operator cycles", ~S"""
    Operator, 2026-09-09: study how to improve the developer iteration cycle with
    interchangeable parts, then twice narrowing what that meant, ending at "developer
    cycle means operator cycles". The study is recorded in
    `logbook-local-gates-before-ci.md`; the ruling it produced belongs here.

    **The machine loops are not the bottleneck, which is the finding that redirected
    the study.** Measured on the desk: the Elixir teacher recompiles in 1.0 s and runs
    its 21 tests in 2.1 s; a no-op `lake build` on the compiler takes 1.3 s once warm,
    against 55 s cold after a sync; prek over the assembly's 377 changed files takes
    49 s; a compiler invocation costs 77 ms. Every inner loop is seconds, so tuning
    them changes nothing the operator experiences.

    **What the operator experiences is round trips, and a third of them were not
    work.** Of 14 operator turns in the session, six carried new direction and five
    were spent putting the work back on track: one question asked three times after
    it had already been answered, one correction of a result reported as clean that
    was not, and two corrections of what was being studied. One session, counted by
    the agent that caused the corrections, so it bounds an order of magnitude rather
    than a rate.

    Three classes, each with a part that already existed and no caller.

    **A sweep with no control reports an empty set as clean.** `repo forall` visits
    zero projects on this desk and exits 0, so a workspace sweep reported 135 visited
    and 0 dirty over nothing at all. The operator caught it. The part was already
    written down: this workspace's own rule that every counter carries a planted
    control, which `check_anti_entropy.py` implements. What was missing was applying
    it to ad-hoc sweeps rather than only to committed gates. There is now one
    enumerator, `Gate.projects/0`, parsed from the manifest and asserting a non-zero
    visit before any result is believed.

    **Defect classes were discovered one CI round trip at a time.** A push failed on
    style after 77.8 minutes, of which 76.1 were queue and 1.7 were checking; the fix
    pushed, and the next run failed on a moved header after 41.8 minutes. Two operator
    turns bought one defect class each, and both were findable on the desk in under a
    minute. So the gate runner runs every mechanism a project declares in one pass
    rather than the operator learning them serially.

    **The relocation class needs its own mechanism, because git reports it clean.**
    Where upstream moves a header rather than editing it, no merge conflicts and the
    break appears only at compile time. It bit this fork four times in one session:
    `audio_stream_generator.h` and `audio_stream.h` moved to `scene/resources/audio/`,
    and the speaker-mode and bus-type names moved from `AudioServer` to
    `AudioServerEnums`. The check is that every engine-rooted include in a changed
    source resolves to a file. On the assembly it runs clean over 377 files with no
    false alarm, and it fails on the real defect naming the file and the include.

    Its floor is stated rather than implied: generated `.gen.h` headers do not exist
    until SCons writes them, and a module-relative include resolves through a CPPPATH
    the check cannot see, so both are excluded and only engine-rooted, non-generated
    includes are checked. A second control asserts the generated case is not flagged,
    because a check that fires on every `.gen.h` is noise, and a noisy gate is
    switched off rather than fixed.

    **The ruling.** A part with no caller is not yet a part. Where the workspace holds
    a mechanism on both sides of a slow boundary, as prek and the 46 committed
    `.pre-commit-config.yaml` files did, the interchangeable-parts obligation is
    discharged by writing the caller, not by writing another mechanism. And a caller
    ships with controls in both directions like any gate: this one shipped without
    them for one revision, passed a working tree carrying two known defects, and was
    decoration until its own third control caught it.
    """

    drafted_by :ai
  end
end
