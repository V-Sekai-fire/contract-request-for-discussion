# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2166. `mix rfd.render` renders rfd/2166-maskscore-cineform-mkv-bundle/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2166 do
  use RFD.DSL

  rfd 2166, "MaskScore Cineform MKV bundle per RFD 1137" do
    state :discussion

    flight_level :l1

    feature "one Cineform MKV per edit bundling the video frames,
audio, and the WebVTT ASR panel (per RFD 1102 task catalog), produced through the
service-cineform pair per RFD 1137."

    scope "`6-datasource/anny-render-corpus`, `7-service/service-cineform`,
`3-interactor/interactor-cineform`, `1-transport/transport-cineform-tui`"

    preamble ~S"""
    Shelved 2026-09-02: no encoding time budget this cycle to build the
    video-delivery bundle; resume when local capacity frees.
    """

    decision ~S"""
    Follow RFD 1137's SKILL.md verbatim: build the encoder + display, run
    the bus, encode one clip per edit at 8 fps with matte + card. Filename
    comes from the citation's title, lowercased with non-word runs
    hyphenated: `anny-mask-score-<edit>.mkv` + matching `.cff`.

    The ASR panel transcripts from RFD 1173.2164.1 become S_TEXT/WEBVTT
    subtitle tracks in the MKV, one per judge, tagged with LANGUAGE
    metadata (auto detect per Whisper for text tracks; ipa/phn-* for
    phoneme tracks).
    """

    problem ~S"""
    RFD 1173 (edit-reward corpus) requires a video-ready asset with a
    .cff title alongside. The Rung 1.5 corpus emits USDZ animation and
    per-view PNGs; neither is a reviewable clip. RFD 1137 (Cineform
    encoder pair) specifies the pair that produces one MKV per
    frame-set.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (MaskScore).
    Follows: urn:oid:1.3.6.1.4.1.66606.1.1.1137 (frame set clip
    encoding).
    """

    drafted_by :ai
  end
end
