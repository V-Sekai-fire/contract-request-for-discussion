# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1152. `mix rfd.render` renders rfd/1152-background-removal-photographic-corpora/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1152 do
  use RFD.DSL

  rfd 1152, "Background removal for photographic corpora" do
    state :published

    feature "background removal"

    attest_in :none

    decision ~S"""
    Background removal uses a photo-trained dichotomous matting model, not a union of
    semantic part masks. `ZhengPeng7/BiRefNet_HR-matting` is the default. It has no
    vocabulary to fall outside of, so it cannot lose a garment for not knowing what
    the garment is.

    See-Through is retained for what transfers -- geometry -- and not for what does
    not -- semantics. Its part masks may be used as regions, never as labels for what
    covers what.

    `DETAILS.md` carries the ground-truth ranking and the dtype it depends on.
    """

    problem ~S"""
    See-Through decomposes a character into semantic layers, and the union of its
    nineteen part masks is an obvious foreground matte. It is already in the
    manifest, already loaded, and on most frames it produces a clean cutout.

    It is the wrong instrument for a photographic corpus, for a structural reason
    rather than a quality one. A union of semantic classes can only keep what it can
    name, and the model is trained on anime characters. Measured on a cosplay
    photograph, a Santa hat scored -8.38 on `headwear` -- a confident negative, not a
    borderline miss -- so the union placed a real garment in the background and
    deleted it. No threshold recovers it; at a threshold low enough to matter the
    union grows from 0.50 to 0.56 of the frame while `headwear` stays empty.

    The same measurement showed the clothing classes fire on body region rather than
    on cloth: a nude torso is labelled `topwear`, and mask-derived coverage reads
    0.81 to 0.93 on images that are largely bare skin.
    """

    related ~S"""
    RFD 1006 covers layer decomposition. RFD 1153 covers how the resulting mattes are
    judged. RFD 1030 records the See-Through components.
    """

    details_title "Background removal for photographic corpora"

    details "Why a matting model rather than a segmenter", ~S"""
    A dichotomous segmenter is trained against binary ground truth, so its only soft
    pixels are silhouette antialiasing; a veil comes back either fully kept or fully
    cut. A matting model is trained against real alpha, so partial transparency is a
    value it can express.

    The scale-free test is soft-alpha pixels per pixel of silhouette perimeter.
    Antialiasing is a constant band along the outline, so it stays near 1 whatever
    the subject. Transparency is area with no perimeter to pay for it.

    Six photographs chosen for sheer fabric, specular surfaces and wispy hair:

    | source | BiRefNet | BiRefNet-matting | HR-matting (2048px) |
    |---|---|---|---|
    | sheer lace | 4.01 | 1.58 | 2.84 |
    | veil | 1.21 | 1.44 | 2.89 |
    | latex | 1.02 | 2.08 | 2.61 |
    | latex | 1.14 | 1.55 | 3.39 |
    | wispy hair | 0.82 | 2.25 | 2.91 |
    | missed garment | 1.85 | 2.94 |, |

    The segmenter clusters near 1.0 as predicted. The matting variants run higher,
    and the high-resolution variant is the most consistent.

    **This ratio ranks model families and must not be read per image.** The 4.01 is
    the highest number in the table and is not transparency: it is a soft uncertainty
    blob. The metric conflates partial alpha with an unsure model.
    """

    details "Cost, and the dtype that decides it", ~S"""
    HR-matting runs at 2048px, 5.7 s per image measured over 27 images on M2 Pro MPS,
    against ~1.2 s for the 1024px variants. Weights are 220M parameters.

    **Float16, not bfloat16.** BiRefNet's ASPP uses deformable convolutions, and MPS
    ships `deformable_im2col_half` but not `deformable_im2col_bfloat`, so bf16 fails
    inside the forward pass while fp16 is fine. Reading that bf16-specific error as
    "no half precision available" forced fp32, and fp32 at 2048x2048 exhausts 32 GB
    of unified memory: one image per five minutes with the machine paging, which looked like the model being infeasible on this hardware. The model
    is feasible: the bf16 error was read as a missing precision. The dtype is
    not about the weights, which are under a gigabyte either way; it is about
    activations, where a single feature map at that resolution runs to gigabytes.
    """

    details "Settled by ground truth", ~S"""
    The alphamatting.com training set has true alpha, so the ordering does not need a
    judge. On the 16 images all three backends completed (lower is better):

    | backend | SAD | Gradient | Connectivity |
    |---|---:|---:|---:|
    | birefnet | 7.09 | 0.076 | 6.00 |
    | birefnet-matting | 4.75 | 0.032 | 3.80 |
    | birefnet-hr-matting | **4.42** | **0.026** | **3.16** |

    `hr-matting < matting < segmenter` on every metric, none dissenting. HR-matting
    separately completed all 27 images alone: SAD 4.48, MSE 1.370, gradient 0.04,
    connectivity 3.97, consistent with the subset.

    This also corrects the `soft_per_perimeter` proxy, which had ranked HR-matting
    first for the right answer by an unreliable route, and RFD 1153's judged ordering,
    which had ranked the segmenter best on gradient, inverted, since ground truth
    puts it roughly 3x worse.
    """

    drafted_by :ai
  end
end
