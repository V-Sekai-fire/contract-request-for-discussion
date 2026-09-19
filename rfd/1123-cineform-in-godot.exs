# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1123. `mix rfd.render` renders rfd/1123-cineform-in-godot/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1123 do
  use RFD.DSL

  rfd 1123, "CineForm in Godot, both directions" do
    state :discussion

    feature "CineForm video decode and encode inside Godot Engine"

    scope "`entities-godot/modules/cineform`, `6-datasource/dataflow-coco-gemx`,\n`3-interactor/pose-consensus`"

    attest_in :none

    decision ~S"""
    Decode and encode CineForm inside Godot, with the GoPro CineForm SDK and not FFmpeg.

    1. **The licence decides this, not the code.** The SDK is `Apache-2.0 OR MIT`, matching our own
       code. FFmpeg is LGPL-2.1 or later, and a Godot export links into one binary, so LGPL asks for
       relinkable objects the SDK does not.
    2. **Carry 12 bits all the way to the texture.** Godot's half float format holds an 11 bit
       significand, so `FORMAT_RGBAH` loses the bottom bit and looks correct. Depth lands in
       `FORMAT_RF`, or stays as integer codes in two 8 bit channels.
    3. **One component, both directions.** The SDK holds an encoder and a decoder, the licence
       argument is the same for each, and splitting them would vendor one dependency twice.
    4. **Expose the track.** A chunk holds two tracks, depth and the alpha-carrying keypoint overlay,
       and a caller chooses between them.
    5. **Verify by round trip, with a negative control.** Encode a known ramp, decode it in Godot,
       compare the texture in millimetres, then run the same check at 8 bit and assert it fails.

    See `DETAILS.md` for the licence argument, 12 bit against 10 bit, the retracted free-codec claim,
    the alternatives, the interfaces, the chunk manifest, and what shipped instead of a GDExtension.
    """

    problem ~S"""
    We write depth as CineForm video in Matroska and Godot cannot read it. Godot 4 ships one video
    codec, Theora, which is 8 bit where our depth needs 12. An 8 bit depth map has 256 steps across
    the body, 6.3 mm per step, about four stacked credit cards, and the renderer measures to better
    than 1 mm. The corpus is 800,000 frames, too many to hold loose: 12 bit CineForm at 1024 by 1024
    costs 127 MB for every 1000 frames, and 16 bit PNG costs about ten times more.
    """

    related ~S"""
    RFD 1121 and RFD 1122 cover the corpus this video carries. RFD 1053 makes OpenUSD the internal
    format for geometry, and this RFD does the same for rendered frames.
    """

    details_title "CineForm in Godot, both directions"

    details "What we measured before proposing this", ~S"""
    The numbers come from FFmpeg 8.1.2 on the local machine. The test is 24 frames at 1024 by
    1024, of a depth ramp with a 0.2 m step in it. The step is there because wavelet codecs do
    their worst at edges. A smooth ramp alone flatters them.

    | pixel format  | bits | MB per 1000 frames | median error | worst error |
    | ------------- | ---- | ------------------ | ------------ | ----------- |
    | `gbrp12le`    | 12   | 127                | 0.46 mm      | 3.3 mm      |
    | `yuv422p10le` | 10   | 94                 | 2.10 mm      | 7.9 mm      |

    Quantisation alone costs 0.39 mm for each step at 12 bit and 1.56 mm at 10 bit. So CineForm
    adds about one step of error and no more.

    0.46 mm is about half the thickness of a credit card. 3.3 mm is about two stacked pennies, and
    it happens only where an arm crosses a torso.

    10 bit is not enough. Its 2.10 mm median is coarser than the 0.54 mm agreement we measured
    between two independent renderers. It would become the largest error in the chain.

    Matroska accepts CineForm. MOV accepts it too and gave identical results. We choose Matroska
    because it is the open container.
    """

    details "Retracted: an earlier claim that the codec was free", ~S"""
    A first probe reported that 97% of codes returned bit exact and that the codec added 0.0 mm.
    That measurement was wrong, and it was wrong in a flattering direction.

    The probe clipped the depth step below the near plane. Clipping produced large flat regions.
    Flat regions compress exactly, so the codec looked perfect on data that was already ruined.

    The corrected probe reports 5.87% of codes exact and a median error of 0.39 mm. The lesson is
    the one this workspace keeps relearning. A check that passes on broken input certifies the
    defect.
    """

    details "Alternatives, and why each fails", ~S"""
    **Link FFmpeg through `EIRTeam.FFmpeg`.** This works today and needs no new code. It brings
    LGPL into every export. We reject it on licence, not on quality.

    **Transcode to VP9 or AV1 for Godot.** Both are open and both reach 12 bit. Both are also
    generational codecs that predict frames. Our depth frames are measurements, and we want each
    frame decoded on its own. Transcoding also adds a second lossy step on top of CineForm.

    **Ship PNG sequences.** This keeps 16 bits and needs no decoder. It costs about ten times the
    space and gives up seeking.

    **Wait for Godot to add a codec.** Godot has shipped only Theora for years. We treat this as
    unavailable rather than late.
    """

    details "What is built, and what is not", ~S"""
    The encoder is written. Its round trip gate runs today and passes. The test pattern holds flat fields, a hard edge and a one
    pixel checker. It returns a median error of 0.00 codes and a worst error of 2.00 codes. The negative control zeroes 8 KB in the middle of the file, and the check
    rejects it at 215 codes.

    The extension has not been compiled. Every SDK symbol it calls was read from the published
    headers rather than recalled. The README lists each one with the header it came from. Reading
    a header is not linking against it, so the first build is part of the work.

    The decoder is not written. This RFD proposes it.
    """

    details "How this gets verified", ~S"""
    The gate is a round trip, not a playback demo. Encode a known depth ramp. Decode it inside
    Godot. Read the texture back. Compare against the source in millimetres.

    Ship a negative control with it. Run the same check through an 8 bit path and assert that it
    fails. A gate that only ever passes has proved nothing about the thing under test.

    Record the decode cost for each frame. A decoder that misses 30 frames each second changes how
    the studio uses this. So the number belongs in the result.
    """

    details "The cheapest thing that could change the plan", ~S"""
    Measure CineForm decode speed on one core before writing any Godot code. The SDK has no
    hardware path. One frame at 1024 by 1024 must cost less than 33 ms to hold 30 frames each
    second. If it costs more, the answer becomes a background decode thread, or still images in a
    different container.

    This costs an hour and needs no engine work.
    """

    details "What shipped, and where this RFD was wrong", ~S"""
    Kept in place rather than rewritten, because a reader who knows which road was tried is better
    off than one who only knows where it ends.

    **The GDExtension route is closed.** `MovieWriter` is not exposed to GDExtension, so an
    exporter has nothing to register against, and godot-cpp would have been a dependency carried
    for an API that cannot be reached. What shipped is an in-engine module: `modules/cineform`
    inside `entities-godot`, with the codec vendored at `thirdparty/cineform` and the muxer at
    `thirdparty/libwebm`.

    **So the Scope line is wrong.** `3-interactor/godot-cineform` was created, used, and deleted.
    The manifest entry went with it. One repository builds this now.

    **Both directions were built.** `MovieWriterCineForm` writes and `VideoStreamCineForm` reads,
    verified against FFmpeg's own `cfhd` decoder rather than against each other.

    **The decode budget was met with room.** The RFD asked for one frame at 1024 by 1024 under
    33 ms on one core. Measured at 1920x1080, encode is 2.51 ms for each frame and the ladder puts
    4K at 11.50 ms, so the background decode thread this RFD held in reserve was not needed.

    **The container is Matroska, not raw CineForm.** AVI caps a file at 4 GB, which these bitrates
    reach in about 56 seconds of 4K60.

    **One measurement contradicts the premise, and is worth stating.** Below 4K the per frame cost
    does not depend on resolution: 640x360 has 36 times fewer pixels than 4K and costs the same
    16.75 ms. The limit under 4K is the window present, not the codec. This RFD assumed decode
    speed would decide the design, and it did not.
    """

    details "The licence argument in full", ~S"""
    Four projects matter here. Three were checked against the GitHub API rather than recalled.

    | project                  | licence                               | role                           |
    | ------------------------ | ------------------------------------- | ------------------------------ |
    | `gopro/cineform-sdk`     | Apache-2.0 OR MIT                     | the codec we propose to vendor |
    | `godotengine/godot`      | MIT                                   | the engine                     |
    | `EIRTeam/EIRTeam.FFmpeg` | MIT                                   | an existing Godot video plugin |
    | FFmpeg                   | LGPL-2.1 or later, GPL in some builds | what that plugin links         |

    The SDK entry is better than the GitHub API reports. The API returns Apache-2.0, because it
    names one licence. The repository holds both `LICENSE-APACHE` and `LICENSE-MIT`, so the SDK is
    dual licensed. That is the same `Apache-2.0 OR MIT` we apply to our own code.

    Read the repository, not the API field. The API picks one licence and a dual licence has two.

    The plugin licence and the dependency licence are different things. `EIRTeam.FFmpeg` is MIT
    and it links FFmpeg. A reader who checks only the plugin sees MIT and stops. The terms that
    reach a shipped game come from FFmpeg.

    This is the same mistake the workspace already recorded about ControlNets. A base model can be
    Apache-2.0 while its control weights are not. So read the licence of the part that does the
    work. Here that part is FFmpeg.

    LGPL-2.1 asks that a user can replace the library. A Godot export is one binary with
    everything linked in. Meeting the condition means shipping relinkable object files or moving
    FFmpeg to a shared library the user can swap. Both are possible. Both add a step to every
    release, forever.

    Apache-2.0 asks for attribution and a patent grant. It adds nothing to the release process.
    """

    details "What CineForm is, and why it suits depth", ~S"""
    CineForm is a wavelet codec. Each frame is complete on its own, so there are no predicted
    frames and no group of pictures. Seeking to frame 41,000 costs one frame of work.

    That property is why it fits a corpus. A training loader reads frames in whatever order the
    sampler asks for. A codec that predicts frames turns a random read into a decode of everything
    since the last keyframe.

    The codec reaches 12 bits for each channel. It also carries alpha in `gbrap12le`, which is
    what the keypoint overlay track needs.
    """

    details "The pixel formats FFmpeg 8.1.2 offers for `cfhd`", ~S"""
        yuv422p10le    10 bit, chroma at half width
        gbrp12le       12 bit planar RGB
        gbrap12le      12 bit planar RGB with alpha

    Depth goes in `gbrp12le`, with the same code written to all three planes. The codec then sees
    no colour detail and spends no bits on it.

    Depth could go in `yuv422p10le` luma alone, and chroma subsampling would not touch it. It is
    still 10 bit, and the table in the README rules that out on precision.
    """

    details "The trap in the texture path", ~S"""
    Godot image formats that hold more than 8 bits for each channel are these.

        FORMAT_RH, FORMAT_RGH, FORMAT_RGBAH     16 bit half float
        FORMAT_RF, FORMAT_RGF, FORMAT_RGBAF     32 bit float

    A half float has an 11 bit significand. A 12 bit integer code needs 12. So a 12 bit code
    cannot round trip through any of the half formats.

    The failure is quiet. The image loads, the depth map looks correct, and the bottom bit is
    gone. Nothing raises and no test that only checks the picture will notice.

    Two ways through, and the choice belongs in the implementation review.

    **32 bit float.** `FORMAT_RF` holds one channel and every 12 bit code exactly. It costs 4
    bytes for each pixel on the GPU.

    **Two 8 bit channels.** Split the code into a high byte and a low nibble. `FORMAT_RG8` costs
    2 bytes for each pixel. The shader recombines them. This keeps memory down and moves the risk
    into shader code that must be tested.
    """

    details "The interfaces to implement", ~S"""
    Godot calls into two classes.

    `VideoStream` describes the file. It reads the path and creates a playback object.

    `VideoStreamPlayback` does the work. These are the virtual methods, read from godot-cpp's
    `extension_api-4-5.json` rather than recalled.

        void _play()
        void _stop()
        bool _is_playing()
        void _set_paused(bool paused)
        bool _is_paused()
        float _get_length()
        float _get_playback_position()
        void _seek(float time)
        void _update(float delta)
        Texture2D _get_texture()
        int _get_channels()
        int _get_mix_rate()
        void _set_audio_track(int idx)

    Our streams carry no audio. The audio calls return zero and no mixer runs.

    `_get_texture` is where the format choice above becomes visible to every consumer.
    """

    details "Retracted: the interface does not drift across minor releases", ~S"""
    A first draft of this RFD warned that the video interface changes between Godot 4 minor
    releases. It told the reader to pin the engine version for that reason.

    That is not true, and it was written from memory rather than measured. The virtual methods of
    `VideoStream`, `VideoStreamPlayback` and `MovieWriter` are identical in
    `extension_api-4-3.json` and `extension_api-4-5.json`. Every signature matches.

    Pin the engine version anyway, because GDExtension has an ABI and a build for one version is
    not automatically loadable by another. Pin it for the ABI, which is the real reason, and not
    for an interface churn that the two files show does not exist.
    """

    details "Two tracks, one file", ~S"""
    Each chunk is one Matroska file with two video tracks.

        track 0    depth, gbrp12le, 12 bit
        track 1    keypoint overlay, gbrap12le, 12 bit with alpha

    `VideoStreamPlayer` plays one track. The extension exposes a track index so a scene can open
    the same file twice and show both.

    The overlay colours follow the OKHSL scheme described below, so a viewer reads layer identity
    from hue without a legend.
    """

    details "The colour scheme the overlay carries", ~S"""
    Each keypoint takes a hue from the See-Through layer it drives. The 24 layer names come from
    `seethrough-torch/training/configs/finetune_layerdiff_iter2.yaml`.

        hue                which See-Through layer the joint drives
        hue plus or minus 6 degrees    which joint inside that layer
        lightness          position along the chain inside the layer
        shape              filled if unoccluded, hollow if the surface is in front

    OKHSL rather than HSL, because HSL lightness is not perceptual. At one fixed HSL lightness the
    yellows glare and the blues sink. A reader then sees brightness differences that mean nothing,
    and misses the lightness differences that carry chain position.

    An earlier draft spread all 104 hues by the golden angle to make neighbours distinct. That is
    the wrong goal. It scattered the five joints of one hand across the whole wheel, so nothing in
    the picture said they belong to one garment region.

    ANNY drives 9 of the 24 layers. The other 15 have no bone at all. The legend lists them greyed
    rather than leaving them out. A category that is simply absent reads as a category that does
    not exist, and RFD 1121 records why that gap matters.
    """

    details "What the chunk manifest must carry", ~S"""
    Quantisation is linear between a near plane and a far plane. Those two numbers invert it. A
    chunk without them is a picture, not a measurement.

        near_m, far_m          the depth band, in metres
        bits                   12
        pix_fmt                gbrp12le
        codec, encoder_version the codec and the FFmpeg build that wrote it
        frame_first, frame_count
        camera                 view matrix, field of view, width, height
        seed                   the render seed, because Mitsuba reproduces from it
        anny_version, git_sha

    The render seed is not decoration. We measured that the same seed returns a bit identical
    image and a different seed changes every body pixel. So the seed is what makes the corpus
    reproducible, and the constructed synthetic rule asks for exactly that.
    """

    details "How decode speed gets measured", ~S"""
    Measure before building. The SDK has no hardware path, so decode runs on the CPU.

    Decode 200 frames at 1024 by 1024 from a written chunk. Report milliseconds for each frame on
    one core, and again with the thread count the SDK offers. State the number of cores used.

    30 frames each second allows 33 ms for each frame. Report the result against that figure
    rather than in isolation, because a number with no baseline is not a measurement.

    If one core cannot hold the rate, the answer is a decode thread that runs ahead of playback.
    That is ordinary work. It is better to know before the extension exists.
    """

    details "Risks", ~S"""
    **The SDK is quiet.** `gopro/cineform-sdk` has few contributors and slow traffic. Vendor it at
    a pinned commit and record the hash. Do not track a moving branch.

    **Windows and Linux both matter.** The desk is Windows where the pods are Linux. Build both from
    the start, because a decoder that works on one is half a decoder.

    **FFmpeg writes the files and the SDK reads them.** Two implementations of one format will
    disagree somewhere. The round trip gate must run against files written by FFmpeg, not against
    files the SDK wrote itself. A codec checked only against its own output has been checked
    against nothing.
    """

    drafted_by :ai
  end
end
