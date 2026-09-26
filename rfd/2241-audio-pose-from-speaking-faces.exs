# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2241. `mix rfd.render` renders rfd/2241-audio-pose-from-speaking-faces/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2241 do
  use RFD.DSL

  rfd 2241,
      "The audio and video leg: keypoints and monocular geometry over a speech corpus, evaluated on constructed bodies" do
    state :discussion

    feature "an audio-pose training corpus built from a licence-clean speech-and-video set by two inference passes, published with its provenance, and measured only on constructed data"

    scope "`3-interactor/rf-detr-cpp` (the keypoint pass), `3-interactor/moge-upstream` (the geometry pass), `3-interactor/taskweft-fbd-teacher` (the selector, packer and tables), `7-service/service-cineform` (the aligned record), and the private Hub repositories the corpus lands in"

    decision ~S"""
    Three of nine camera positions from one trial, visual only, read by byte range
    rather than downloaded. Keypoints from the validated RF-DETR head, per-frame
    metric geometry from MoGe-3. Both halves of the label are inferred, so the
    corpus is generated synthetic under the four conditions the agreements set.
    The fourth cannot be met by holding out subjects, because a held-out MoGe
    label is still a MoGe label, so **the evaluation arm is constructed**: ANNY
    bodies rendered through the existing pipeline. Parked 2026-09-08.
    """

    problem ~S"""
    Operator, 2026-09-08: "can you do the cineform audio leg. I want to train
    audio and video leg with detr keypoint and audio-pose, but I can't pay for
    both this and the fbd trait work."

    So the leg had to fit beside the FBD trait work rather than compete with it,
    and answer for labels no human checked. An earlier draft triangulated across
    calibrated views; that was wrong, and the retraction is kept.
    """

    references ~S"""
    - `IS2AI/SpeakingFaces`, CC BY 4.0 with MIT code, DOI 10.3390/s21103465, Hub revision `eb2f8226`
    - RF-DETR's keypoint head, Apache-2.0 in the Nano family; the object-detection head stays blocklisted
    - MoGe-3, placed at `3-interactor/moge-upstream` and pinned at `74fbce0`; RFD 1123 for CineForm
    """

    related ~S"""
    - RFD 2239 records the identity drop and this park; RFD 2234 the renderer the constructed arm reuses.
    """

    details_title "The audio and video leg: keypoints and monocular geometry over a speech corpus, evaluated on constructed bodies"

    details "What the labeler already is, which is most of what this would have cost", ~S"""
    `3-interactor/rf-detr-cpp` is a C++ port of RF-DETR over the workspace's one
    ggml, with the keypoint head validated end to end against the PyTorch
    reference: boxes to 3.5e-3, logits to 9.3e-4, keypoints to 4.2e-3. It carries
    the dual projector and the AdaLN-modulated GroupPose decoder stream, runs with
    no PyTorch at runtime, and already has its GGUF converters and a Hailo compile
    path.

    So the video half of this leg is inference through a part that exists. What it
    needs is a batch entry point over a frame sequence and the checkpoint hash in
    its output, not a port.
    """

    details "What gets read, and why it is a fraction of the set", ~S"""
    The command session runs about 26,000 frames per subject across 9 camera
    positions and 2 trials, so one position-and-trial slot is about 1,444 frames,
    48 seconds at 30 fps.

    Audio-pose needs continuous aligned sequences, so time is not sampled. What is
    selected instead is **3 camera positions of 9, one trial, visual stream only**.
    Three rather than one because a single view cannot disagree with itself, and
    the agreement check below needs several independent reconstructions of the same
    instant. Visual only, because the thermal stream carries no pose information
    this task does not already have.

    That is 3/18 of the audio session: about 4,300 frames per subject, 615,000
    frames across 142 subjects, roughly 215 GB read, against 920 GB for the whole
    audio session and 2.15 TB for the set.

    The read is by byte range, not by download. A zip's central directory sits at
    its tail and each member is independently deflated, so a seekable HTTP file
    lists a zip and then fetches only the members wanted. `huggingface_hub`'s
    filesystem hands out that object and `zipfile` takes it directly. That
    technique is the one thing worth keeping from the silent-stills leg retracted
    in the same session.
    """

    details "Where the geometry comes from, correcting an earlier draft", ~S"""
    An earlier version of this leg triangulated keypoints across calibrated views.
    Operator, 2026-09-08: "I don't know if we have meshes for speaking faces, we
    were supposed to use moge3 on it." There are no meshes, and there is no
    calibration to triangulate against.

    MoGe-3 recovers metric point maps, depth, normals and camera field of view from
    a single open-domain image. Geometry is therefore estimated per frame rather
    than triangulated, and no calibration is assumed or needed. `moge-upstream` is
    placed and pinned at `74fbce0` with `moge/model/v3.py` present.

    The triangulation claim is retracted here rather than quietly replaced, because
    a reader who knows which road was a dead end is better off than one who only
    sees the current answer.
    """

    details "Both halves of the label are inferred, and what that obliges", ~S"""
    Keypoints come from RF-DETR and geometry from MoGe-3, so a model trained on
    this corpus is a student of two teachers, and the corpus is generated synthetic
    under the working agreements. Three of the four conditions are bookkeeping:
    both model names, checkpoint hashes and revisions recorded per row; the corpus
    stored and manifested separately from constructed and real data; never the sole
    distribution for anything deployed on real inputs.

    The fourth condition, that evaluation uses real or constructed data only,
    cannot be met by holding out subjects. A held-out MoGe label is still a MoGe
    label, so a subject holdout measures agreement with the teacher rather than
    agreement with the world. So:

    - **Training** is the real photographs, with MoGe-3 geometry and RF-DETR
      keypoints.
    - **Evaluation is constructed**: ANNY bodies rendered through the pipeline
      that already exists, where landmark positions are exact by construction.

    That is the doctrine's own allowance for constructed data, it needs no new
    machinery, and it is the only arm that can honestly report an error in
    millimetres.
    """

    details "What is checked, since it cannot be called measured", ~S"""
    The three camera positions give independent monocular reconstructions of the
    same instant. Registering them to each other leaves a residual, and that
    residual is a real quantity: it says whether the two models agree with
    themselves across viewpoint. It does not say whether they are right.

    Frames whose views disagree beyond a stated bound are dropped and counted,
    never skipped in silence, and the residual distribution ships with the corpus
    in millimetres with its household equivalent beside it, on the reporting rule
    that "4.3 mm" tells a reader nothing while "about three stacked pennies" does.
    The card says "consistency check, not ground truth" in those words.

    This also settles the view count. Three positions is the fewest that can
    disagree; nine makes the check sharper at three times the transfer. The choice
    is recorded with the measured residual that justified it, rather than asserted
    here.

    One thing is assumed and must be measured before the rest run: that MoGe-3's
    metric scale is good enough on faces at this framing for the agreement residual
    to be informative rather than dominated by scale error. One subject settles it.
    A residual that swamps the signal is a finding, not a bound to widen.
    """

    details "What is published, in two deliberately different sizes", ~S"""
    The **training corpus** is audio and keypoint tracks: 16 kHz audio bytes per
    utterance, the per-view 2D tracks, MoGe-3's metric point sample at each
    keypoint, and the cross-view agreement residual. Payload lives in the parquet,
    as every artefact in this workspace does, because a path is not the data and a
    publisher drops what a path points at. This is single-digit GB and is what an
    audio-pose model consumes.

    The **CineForm clips** are the aligned record and the surface a person can
    watch, published for a bounded subset rather than all 426: the 22 evaluation
    subjects. Each clip asserts `mix_rate >= fps`, even dimensions (768x512 is
    even), and `total_frames` as a cap rather than a hint.

    Every published repository is private and carries its `CITATION.cff`. The
    likeness and consent RFD gates any public re-host, and until it lands this
    corpus stays private.
    """

    details "What the set holds, recorded once", ~S"""
    142 subjects, 9 camera positions, two trials, a silent session and a
    command-reading session. Thermal at 464x348 and visual at 768x512 with stereo
    audio. 2.15 TB in 283 zips: `image_only/sub_N_io.zip` from 1 to 10.4 GB, with
    `sub_2_io.zip` at 0 bytes, and `image_audio/sub_N_ia.zip` from 4.6 to 8.4 GB.
    About 48,600 stills and 26,000 command frames plus 176 wav files per subject,
    10.6 M frames in all.

    `metadata/subjects.csv` carries Sub_ID, Split (Train 100, Valid 20, Test 22),
    Age 20 to 64 with a median of 28, Gender at 74 male and 68 female, Ethnicity at
    90 Asian, 46 Caucasian and 6 Black, and Acc_Trial_1/2.

    `sub_2_io.zip` is named as empty in the manifest rather than skipped, because
    an unmet precondition that goes unnamed reads exactly like a pass.
    """

    details "Cost, which is the part that answers the operator's constraint", ~S"""
    Transfer is about 215 GB by ranged read, an afternoon. Two inference passes run
    over the same 615,000 frames on the 4090: RF-DETR keypoints with a Nano-family
    head, on the order of one to three hours, and MoGe-3, which is the heavier of
    the two and is measured on one subject before the rest rather than estimated
    here. CineForm encoding of 426 clips of about 1,444 frames each, at the
    measured floor above 600 fps, is under twenty minutes. Training the audio-pose
    model is hours on one card, not days.

    The two workloads sit on different devices, so scheduled together they cost
    about the larger rather than the sum. The FBD trait rows are CPU-bound, being
    compiler runs, headless engine launches, the planner and float64 rig solves,
    while this leg is GPU-bound. So the FBD writer runs at 6 workers on the 8-core
    desk while keypoint inference holds the 3090 and audio-pose training holds the
    4090, leaving two cores for the training loader. That claim is made the way the
    levelling discipline demands: measured on the first pair, combined throughput
    against sequential, and kept only if it wins.

    If the overlap does not pay, the staged row counts are the budget lever. Every
    trait at 10,000 rows is about 8 to 9 hours across all of them; the promotions
    to 100,000 are the other 72 to 81. Rows are allocated by seed range, so a
    promotion appends rather than rewrites, and deferring every promotion until
    after this leg lands costs time-to-100,000 and nothing else. Nothing is cut and
    nothing is redone.
    """

    details "What this RFD does not decide", ~S"""
    The audio-pose model itself. This document builds a corpus and states the rule
    its evaluation must satisfy; the architecture, the training run and its
    measurements are their own RFD rather than a line here.

    Nor does it decide the likeness and consent question. That gates a public
    re-host, not the private corpus, and it is named here so the dependency is
    visible rather than discovered later.
    """

    drafted_by :ai
  end
end
