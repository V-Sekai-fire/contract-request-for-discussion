# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1136. `mix rfd.render` renders rfd/1136-camera-vocabulary-and-the-96-pose-grid/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1136 do
  use RFD.DSL

  rfd 1136, "Views are named in the ecosystem's camera vocabulary" do
    state :discussion

    feature "naming camera directions, and a grid of them as training data"

    scope "`7-service/service-livebook/priv/python/weft_loop.py`"

    attest_in :none

    decision ~S"""
    Name a view in the vocabulary fal's Multiple-Angles LoRA is conditioned
    on: 8 azimuths at 45 degree steps, 4 elevations at -30, 0, 30 and 60, and
    3 distances at 0.6, 1.0 and 1.8. It then reads the same to a person, a
    tagger and a generator.

    `camera_prompt` converts parameters to the prompt and `camera_parameters`
    converts back, both exactly. A camera the table does not name is a refusal
    rather than the nearest phrase, because a snapped name describes a picture
    nobody rendered. `describe_camera` is the lossy direction and says so,
    naming the band that holds a camera and refusing outside it.
    `sample_camera` draws inside a band, and its seed is required.

    The 96 cells are enumerated in `test_weft_loop.py`, not sampled, and that
    found the front view's band wrapping through zero.

    Only the phrase table is used. Qwen-Image-Edit is blocklisted and those
    weights are gated, so neither is loaded. `logbook/CITATION.cff` cites it.
    """

    problem ~S"""
    This workspace named views in degrees. "Pitch -90, yaw 0" says nothing
    about what a picture shows, and a reader has to hold the up axis and the
    rotation order in their head to find out.

    The cost was not cosmetic. Loop 1 scored view 0 of its sequence for three
    rounds and got 0.0 each time. View 0 is a camera directly beneath a
    standing figure. The degrees were on the page the whole time.
    """

    related ~S"""
    RFD 1134 records the run where the unnamed view cost three rounds. See
    `DETAILS.md` for the grid proposed as constructed training data.
    """

    details_title "Views are named in the ecosystem's camera vocabulary"

    details "The vocabulary, verbatim", ~S"""
    | azimuth | phrase                    |
    | ------- | ------------------------- |
    | 0       | front view                |
    | 45      | front-right quarter view  |
    | 90      | right side view           |
    | 135     | back-right quarter view   |
    | 180     | back view                 |
    | 225     | back-left quarter view    |
    | 270     | left side view            |
    | 315     | front-left quarter view   |

    | elevation | phrase          | distance | phrase      |
    | --------- | --------------- | -------- | ----------- |
    | -30       | low-angle shot  | 0.6      | close-up    |
    | 0         | eye-level shot  | 1.0      | medium shot |
    | 30        | elevated shot   | 1.8      | wide shot   |
    | 60        | high-angle shot |          |             |

    The trigger token is `<sks>` and the order is azimuth, elevation,
    distance: `<sks> front view low-angle shot close-up`.
    """

    details "What the bands are, and why the inverse is not a function", ~S"""
    A phrase is a band where a parameter is a point, so reading a prompt back
    gives an interval. Boundaries sit midway between neighbours. Distance
    boundaries are geometric, because 0.6, 1.0 and 1.8 are multipliers: the
    arithmetic midpoint of 0.6 and 1.0 is 0.8 and the geometric one is 0.775,
    and the second sits midway in the quantity being scaled.

        azimuth    front view [337.5, 22.5)  and seven more at 45 degree steps
        elevation  low-angle [-45, -15)  eye-level [-15, 15)
                   elevated [15, 45)     high-angle [45, 75)
        distance   close-up [0.4, 0.775) medium [0.775, 1.342) wide [1.342, 2.2)

    The front view's band wraps through zero. `in_band` knows that and a bare
    comparison does not: the enumeration found 36 sampled front views in 480
    that a naive check placed in no band at all.
    """

    details "The render sequence in that vocabulary", ~S"""
    Five of the eight views `sphere_hammersley_sequence` produces at n=8 have
    no phrase, because their elevations sit between the vocabulary's steps.

    | view | azimuth | elevation | phrase                                    |
    | ---- | ------- | --------- | ----------------------------------------- |
    | 0    | 0       | -90       | none. -90 is below the -45 band floor     |
    | 1    | 180     | -30       | back view low-angle shot medium shot      |
    | 2    | 90      | 0         | right side view eye-level shot medium shot |
    | 3    | 270     | 9.6       | left side view eye-level shot medium shot |
    | 4    | 45      | 19.5      | front-right quarter view elevated shot    |
    | 5    | 225     | 30        | back-left quarter view elevated shot      |
    | 6    | 135     | 41.8      | back-right quarter view elevated shot     |
    | 7    | 315     | 56.4      | front-left quarter view high-angle shot   |

    Views 3, 4, 6 and 7 have no exact phrase and take the band that holds
    them. View 0 has neither.
    """

    details "The grid as constructed training data, and the rule it collides with", ~S"""
    The proposal is to render the ANNY corpus through all 96 poses, pairing
    each render with the prompt that names it. The provenance is better than
    the LoRA's own: these are constructed synthetic, rendered deterministically
    from assets we hold, so the labels are true by construction and the same
    seed reproduces the corpus. fal's page says "3000+ Gaussian Splatting
    renders" and names no engine, no assets and no image count, so their grid
    is reusable and their corpus is not reproducible from what is published.

    CLAUDE.md says views come from `sphere_hammersley_sequence` and that a
    different camera sequence is not chosen instead. A 96-pose grid is a
    different camera sequence, so this needs deciding rather than doing.

    The distinction that resolves it, if it is accepted: the Hammersley
    sequence exists to measure error without a view being picked to flatter
    it, and the grid exists to pair a render with the words for its camera.
    The first is a measurement instrument where the second is a label. A grid
    used for measurement would be the failure the rule was written for, and
    the rule should say which of the two it governs.
    """

    details "What it costs", ~S"""
    Measured on this desk at 1024 by 1024, 128 spp:

    | renderer                 | per frame | 96 poses  | reproducible |
    | ------------------------ | --------- | --------- | ------------ |
    | `llvm_ad_rgb`, 1 thread  | 78 s      | 2 h 5 min | yes          |
    | `cuda_ad_rgb`            | under 1 s | under 2 min | no         |

    Corpus data is compared across time, so the corpus grid is the llvm row.
    Two hours per subject is the number to plan against, and it is the reason
    this is a decision rather than a script somebody runs tonight.
    """

    details "Can the Hammersley sequence cover the 96 poses? No, and twice over", ~S"""
    ### It has no distance axis at all

    `sphere_hammersley` returns a yaw and a pitch. The radius is not part of it:
    `render_view.camera` computes `sqrt(3)/2/sin(fov/2)`, one distance fixed by
    the field of view, and the CLI exposes no distance flag. So the sequence
    addresses 32 of the 96 poses at most, and the three distances are a
    multiplier that would have to be added to `render_view` before any of this
    is renderable.

    ### It does not land on the grid either

    Coverage of the 32 azimuth-by-elevation cells, measured as the great-circle
    angle from each cell to the nearest sequence point:

    | n    | within 1 deg | within 2 deg | within 5 deg | worst cell |
    | ---- | ------------ | ------------ | ------------ | ---------- |
    | 8    | 3 of 32      | 3 of 32      | 4 of 32      | 60.0 deg   |
    | 32   | 1 of 32      | 1 of 32      | 1 of 32      | 36.9 deg   |
    | 96   | 0 of 32      | 0 of 32      | 5 of 32      | 19.9 deg   |
    | 192  | 0 of 32      | 0 of 32      | 8 of 32      | 12.9 deg   |
    | 384  | 0 of 32      | 0 of 32      | 16 of 32     | 10.8 deg   |
    | 768  | 0 of 32      | 0 of 32      | 24 of 32     | 7.6 deg    |
    | 1536 | 0 of 32      | 0 of 32      | 32 of 32     | 3.8 deg    |
    | 3072 | 0 of 32      | 24 of 32     | 32 of 32     | 2.1 deg    |
    | 6144 | 24 of 32     | 32 of 32     | 32 of 32     | 1.2 deg    |

    Covering every cell to 5 degrees takes 1536 renders, to 2 degrees 3072, and
    1 degree is not reached at 6144 for eight of the cells. On the card that is
    26 minutes, 51 minutes and over an hour and a half; at llvm's 78 s a frame
    the first row of that is 33 hours, for one subject.

    The count of exact hits FALLING as n goes from 8 to 32 is not noise. At n=8
    the radical inverse in base 2 gives azimuths of exactly 0, 180, 90 and 270,
    and three of those points also land on an elevation the vocabulary names.
    Those three are precisely the three views of the n=8 sequence that
    `describe_camera` names exactly. Larger n fills the sphere with points that
    are near the grid and not on it.

    ### So they answer different questions

    A low-discrepancy sequence exists to cover a sphere without a view being
    chosen, and a grid exists to put a known camera beside a known phrase. Asking
    the sequence to reproduce the grid spends 1536 renders to approximate 32
    poses that can be written down exactly. The grid is 96 lines of parameters.

    The recommendation is therefore to generate the grid directly for labelled
    pairs and keep the sequence for measurement, and to add a distance multiplier
    to `render_view` before either. That leaves CLAUDE.md's rule about the
    sequence intact for what it governs, which is measurement.
    """

    details "The sweep is a video, not 96 loose files", ~S"""
    `transport-cineform-tui` already encodes CineForm into Matroska, RGB_444 or
    RGBA_4444 with `-alpha`, driven through `service-cineform`. A 96-pose sweep
    is 96 frames of one subject, so it is a clip rather than a directory, and the
    deliverables rule already asks for a video or image intermediate carrying a
    `.cff` title and metadata.

        cineform-tui [options] sweep-<subject>.mkv

    The grid's enumeration order is what makes this work: azimuth runs fastest,
    so frame index maps to pose, and a truncated file is a partial sweep of one
    elevation rather than a partial sweep of everything.

    Three things to settle before it replaces the PNGs.

    - **The frame hash changes meaning.** CineForm is visually lossless and is not
      bit-exact, so a decoded frame will not carry the PNG's sha256. Either the
      hash moves to the container, or the per-frame hash stops being the check it
      is now. This is the reason to decide rather than to switch quietly.
    - **The labels must stay machine-readable.** The per-frame camera parameters
      and their prompts belong in a parquet beside the clip, keyed by frame index,
      or in the container's tags. A clip whose labels live only in a filename is
      not a corpus.
    - **Alpha is a choice.** The renders are RGB today. A matte needs
      `-alpha` and RGBA_4444, which is a different encode and a different size.
    """

    details "The encode is not the cost, and here is the arithmetic", ~S"""
    `interactor-cineform` reports its own throughput on a 16-thread CPU: 6 frames
    of 1920 by 1080 in 67 ms, about 112 fps, and 60 frames of 640 by 360 in
    40 ms, about 1810 fps.

    A sweep is 96 grid poses plus the 48-view sequence, so 144 frames of 1024 by
    1024. At the measured 1080p rate that is 1.3 seconds. Scaling by pixel count
    suggests about 220 fps at this frame size and so 0.7 seconds, and that figure
    is an extrapolation rather than a measurement, which is why both are given.

    Against the render it disappears. 144 frames on the card is about 144
    seconds, and at llvm's 78 s a frame it is 3 hours 7 minutes. The encode is
    under one percent of the fast path and a rounding error on the slow one.

    So the container is free and the question the previous section raises is the
    only one that matters: what the frame hash means once the frames are
    visually lossless rather than identical.
    """

    details "The subjects behind these numbers", ~S"""
    Two of the three subjects rendered through this grid were deleted on
    2026-08-25 as invalid poses: the hv_1 fit at a chest facing of 345.9
    degrees and the hv_2 fit at 72.7. Both came from an unconstrained
    17-point solve, and both crossed limbs across the body while reporting a
    residual under 0.04% of stature.

    The ANNY rest pose at 270 degrees is the surviving subject and the one
    the grid's own citation names. The facings are kept here because they
    are what made the phrases correct, and because a reader who finds only
    the rest pose should know the other two existed and why they do not.
    """

    drafted_by :ai
  end
end
