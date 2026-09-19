# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1168. `mix rfd.render` renders rfd/1168-segmenting-the-3d-latent-with-rf-detr/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1168 do
  use RFD.DSL

  rfd 1168, "Segment the 3D latent with rf-detr, and treat masking as corruption" do
    state :ideation

    feature "layer decomposition without See-Through"

    scope "`3-interactor/rf-detr-cpp`, `3-interactor/voxhammer-upstream`"

    attest_in :none

    decision ~S"""
    Segment in 3D, from parts already held. RF-DETR-Seg has a
    `SegmentationHead` that `convert_segmentation_to_gguf.py` converts, so
    the segmenter is the one model at rung 3. VoxHammer's
    `extract_feature.py:96` projects per-view tensors onto voxel centres
    with `F.grid_sample`, over the `sphere_hammersley_sequence` views
    CLAUDE.md mandates. **The lift is that call with a different payload:**
    class logits where DINOv2 patch tokens go now.

    3D is the right place: `front hair` against `back hair` is a depth
    relation, and a rendered view is where it is destroyed.

    **Masking is corruption.** A layer is only a layer if it is whole, so
    emitting `back hair` means restoring what `front hair` hid.

    **LaMa fills the hole, and is the licence-clean half of See-Through** —
    `dreMaz/AnimeMangaInpainting`, MIT over Apache-2.0, tuned for this
    domain. It will not compile: its Fourier convolutions call `rfftn`, and
    no Fourier operator is in `DEVICE_OPS`. CycleGAN is the opposite trade.

    **Unbuilt.** `DETAILS.md` bounds the COCO classes and the resolution,
    supplies the corpus from corrupt-clean render pairs, and gives two
    tests costing no training.
    """

    problem ~S"""
    RFD 1166 dropped See-Through, so layer decomposition has no model. The
    obvious 3D replacement is gone too: P3-SAM / Hunyuan3D-Part is
    blocklisted on a territory-restricted licence.
    """

    related ~S"""
    RFD 1166 drops See-Through. RFD 1167 places rf-detr at rung 3.
    """

    details_title "Segment the 3D latent with rf-detr, and treat masking as corruption"

    details "The three pieces, and where each is", ~S"""
    Nothing here is proposed from scratch. The proposal is a payload change
    to a call that already runs.

        piece               where it is                          state

        the segmenter       rf-detr, SegmentationHead, and
                            `convert_segmentation_to_gguf.py`    in tree
        the lift            `voxhammer/extract_feature.py:96`,
                            `F.grid_sample(patchtokens, uv...)`  in tree
        the views           `sphere_hammersley_sequence` in
                            `trellis/utils/random_utils.py`      in tree
        the label set       `VALID_BODY_PARTS_V3`, 23 parts,
                            `common/live2d/scrap_model.py`       in tree

    **`grid_sample` does not care what the channels mean.** Today it carries
    1024 DINOv2 channels onto voxel centres. Carrying 23 class logits
    instead is the same call with a different tensor, and the uv it samples
    at is computed from the camera the renderer already used.

    **The segmenter is the one model at rung 3.** RFD 1167 records rf-detr
    as the only candidate the Dataflow Compiler has accepted, 825 nodes,
    22 operators, nothing outside `DEVICE_OPS`. A segmentation head is small
    beside the backbone it sits on, so the device half already measured is
    most of this.
    """

    details "Why 3D is the right place, rather than a workaround", ~S"""
    The layer names that matter are depth relations wearing appearance
    names. `front hair` and `back hair` are not two textures, they are the
    same material on either side of the head, and **a rendered view is
    exactly where that distinction is destroyed**, from the front, one
    occludes the other and the pixels do not say which is which.

    This is the same fact CLAUDE.md states from the other side when it says
    a photograph has no ground-truth `front hair` / `back hair` split, and
    why the blinded COCO holdout cannot validate this task. A 2D segmenter
    is being asked for something its input does not contain.

    Voxel centres carry it for free. Behind-the-head is a coordinate, not an
    inference, so the split that is hardest in 2D is nearly free in 3D.
    Multi-view voting over the Hammersley sequence then settles the parts
    that are genuinely appearance rather than depth.
    """

    details "Masking is corruption, and it is what makes the layers whole", ~S"""
    Segmentation alone does not produce layers. It produces regions of a
    surface, and a layer that stops where another one covered it is not a
    layer, it is a silhouette with a bite taken out. `back hair` has to
    come out whole or it cannot be posed, restyled or painted on.

    **So cut the occluder and call the hole corruption.** Remove `front
    hair` and what is behind it is missing rather than wrong, which is the
    shape of problem inpainting already solves. Neither candidate for that
    job segments: rf-detr says where the boundary is, the mask makes the
    hole, and the inpainter fills it.
    """

    details "Two inpainters, and the choice is licence against accelerability", ~S"""
    **LaMa is what See-Through used, and it is licence-clean.**
    `annotators/lama_inpainter` loads `lama_large_512px.ckpt` from
    `dreMaz/AnimeMangaInpainting`, which is **MIT**, over upstream LaMa code
    which is **Apache-2.0**. Unlike every See-Through checkpoint RFD 1166
    blocklists, this one carries a real grant, so the useful part of that
    project survives its licensing twice over, once as the taxonomy and once
    as this.

    It is also already the right domain. The checkpoint is fine-tuned for
    anime and manga, which is the illustration domain the whole task sits
    in, and it is a purpose-built inpainter rather than something adapted
    into the role.

    **And it will not compile for the accelerator.** LaMa is built on Fast
    Fourier Convolutions: `ffc.py` calls `torch.fft.rfftn`, and no Fourier
    operator appears anywhere in `DEVICE_OPS`. RFD 1131 names the refused
    families and this is a new one, not data-dependent indexing, simply
    absent from the allowlist. LaMa runs on the host or it does not run.

    **CycleGAN is the opposite trade.** It is a ResNet-9block generator,
    plain convolution throughout, which is why RFD 1166 scores it 95 on
    `shape`, second only to rf-detr. It would compile. But it is an
    unpaired translation model rather than an inpainter, so using it here
    means training it for hole-filling, and the corruption pairs below are
    exactly the supervision that would take.

        inpainter   licence            domain        compiles

        LaMa        MIT / Apache-2.0   anime, manga  no, rfftn is not
                                                     in DEVICE_OPS
        CycleGAN    BSD-3-Clause       untrained     yes, plain conv
                                       for this

    So the recommendation is LaMa on the host for quality, and CycleGAN as
    the option if this ever has to run on the device. That is a decision
    about where the stage runs, not about which model is better, and it does
    not need making until something forces it.

    **The framing is worth more than the mechanism, because it supplies the
    corpus.** The first bound below is that a segmenter has no labelled data
    for this taxonomy. Corruption pairs do not have that problem:

        render an asset with every layer          -> the clean target
        render it again with one layer hidden     -> the corrupt input
        the difference                            -> that layer, whole

    Both frames come from the same rig, the same seed and the same camera
    sequence, so the pair is exact, with the label true by construction. No
    annotator, no inference, and no generated data, this is the
    constructed synthetic CLAUDE.md admits as ordinary training data, with
    `syn_data.py`'s Live2D renders as the reference case.

    **It is also a negative control for free.** Hide a layer that is fully
    occluded from a given view and the corrupt and clean frames are
    identical; a model reporting a difference there is reporting noise. A
    pipeline that cannot produce that case has not shown its difference
    means anything.
    """

    details "The first bound: the segmenter does not know these classes", ~S"""
    RF-DETR-Seg is trained on COCO. It segments `person` and `object`, and
    knows nothing of `topwear`, `earwear` or `back hair`. **The proposal
    needs a retrain onto `VALID_BODY_PARTS_V3` and that needs labelled
    data.**

    That is the same wall RFD 1166 records for Kimodo, reached from a
    different direction: the model is available where the corpus is not. What
    is on hand:

    - **Constructed synthetic is the honest candidate, and the corruption
      framing above is how it is generated.** Live2D drawables
      and ANNY rigs render deterministically with labels true by
      construction, and `VALID_BODY_PARTS_V3` came out of a Live2D scraper
      in the first place, so the vocabulary and the assets already agree.
      This is ordinary training data under CLAUDE.md, not generated data.
    - **The blinded holdout cannot validate it**, for the reason above. Held
      out illustrations are needed and this workspace does not have a
      labelled set of them.
    - **See-Through's own weights cannot supply labels.** They are
      blocklisted, and using a blocklisted model as a teacher would carry
      its licence into the student, which is the propagation the OpenRAIL-M
      row exists to stop.
    """

    details "The second bound: the latent is coarser than the taxonomy", ~S"""
    The sparse structure stage emits a voxel grid, and the taxonomy's finest
    parts are far below it. `irides`, `eyewhite`, `eyelash` and `eyebrow`
    are millimetres on a face, about a credit card's thickness, 0.76 mm,
    for a lash, and no voxel in a structure latent is that small.

    So the reachable label set is the coarse half: `front hair`,
    `back hair`, `headwear`, `topwear`, `bottomwear`, `legwear`, `footwear`,
    `tail`, `wings`. The eye and mouth parts are not reachable here at any
    segmenter quality, and a result claiming them would be reporting the
    segmenter's 2D confidence rather than anything the latent holds.

    **This is worth stating before anyone measures it**, because a run that
    scores well on nine coarse parts and badly on four fine ones will look
    like a model problem and is a resolution problem.
    """

    details "Laddering, and what the Embedder's Dilemma actually says", ~S"""
    El Assadi, Muennighoff and Lee, *The Embedder's Dilemma: LLMs Are
    Better, but at What Cost?*, arXiv:2608.12875, COLM 2026. **An earlier
    revision of this section applied the title and admitted to not having
    read the paper. The paper is stronger than the title, and the numbers
    are the argument:**

        best LLM (Gemini 3.1 Pro)      77.6
        best embedding model           77.2      0.4 points apart

        cost per benchmark pass        USD 154 against USD 0.11    1431x
        tokens on the same GPU         2.5x to 736x slower

    Its recommendation is not "prefer the small model". It is **stratified
    by task class**: embedding models for similarity, classification and
    clustering; LLMs reserved for reasoning-intensive retrieval, which is
    where they actually lead rather than tie.

    That distinction is the useful import here, and it is sharper than the
    laddering this document was already doing. A ladder asks how far up to
    climb. Stratification asks whether the expensive rung is better *at this
    task* or only in aggregate, and a 0.4-point aggregate gap at 1431x the
    cost means the aggregate was hiding the answer.

    Applied to each choice below:

        stage        task class         what it implies

        segment      classification     rf-detr, and the paper says a small
                     per voxel          model ties here rather than losing
        inpaint      generation         the expensive model plausibly does
                                        win, so measure before economising
        score a      judgement, and     REACHES RFD 1166, see below
        proposal     possibly retrieval

    **The scoring row is where this reaches beyond this RFD.** RFD 1166
    ranks EditScore, a LoRA over Qwen3-VL-8B at 6.75 GiB, as the gate that
    accepts or rejects a proposal. If that gate is doing classification --
    is this edit good, the paper's finding is that an embedding model ties
    an LLM at a fraction of the cost, and 6.75 GiB is most of the device's
    8 GB. If it is doing reasoning-intensive judgement, the LLM earns its
    place. **Nobody here has established which**, and the two answers differ
    by roughly three orders of magnitude in cost.

    That is a question for RFD 1166 rather than this document, and it is
    recorded here because this is where the paper was raised.

    **The inpainter choice is not an instance of the dilemma**, and saying
    so keeps the analogy honest. LaMa against CycleGAN is quality against
    *accelerability*, not quality against cost, LaMa is small and cheap
    and simply contains an operator the compiler refuses. A framework about
    paying more for better does not decide it.
    """

    details "What would settle it, in the order it should be tried", ~S"""
    1. **Carry a constant through the lift.** Replace `patchtokens` with a
       one-hot tensor and confirm the voxels come back labelled. This tests
       the plumbing and needs no trained segmenter at all.
    2. **Carry COCO `person` through it.** The stock RF-DETR-Seg checkpoint
       already emits this, so a whole-body mask lifting cleanly onto the
       latent is a real end-to-end result on an untrained taxonomy.
    3. **Only then retrain**, on constructed synthetic, against the nine
       coarse parts rather than all 23.

    Steps 1 and 2 cost no data and no training, and either can refute the
    proposal on its own. Doing them before the retrain is the difference
    between finding out in an afternoon and finding out after a corpus.
    """

    details "What this does not claim", ~S"""
    It does not claim either inpainter decomposes anything. rf-detr finds
    the boundary; the inpainter only makes the remainder whole. Naming the
    inpainter the decomposer would put the work in a component that cannot
    do it.

    **It does not claim the inpainting happens in the latent.** LaMa is a
    2D image model, so on the obvious reading it completes rendered views
    which are then lifted, and the layers are assembled from multi-view
    agreement rather than repaired in three dimensions. Completing the
    latent directly is a different and harder thing, and nothing here has
    shown which one the task needs.

    It does not claim parity with See-Through. See-Through decomposes an
    illustration into raster layers a person can paint on; this labels a
    sparse latent and fills what a mask removed. They answer different
    questions and only one of them is available.
    """

    drafted_by :ai
  end
end
