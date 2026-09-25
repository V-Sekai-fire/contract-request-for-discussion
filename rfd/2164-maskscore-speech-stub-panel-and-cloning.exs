# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2164. `mix rfd.render` renders rfd/2164-maskscore-speech-stub-panel-and-cloning/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2164 do
  use RFD.DSL

  rfd 2164, "MaskScore Speech-stub 12-track ASR panel + 10-rank voice cloning" do
    state :discussion

    flight_level :l1

    feature "MaskScore Speech stub filled along two axes -- a panel of
diverse ASR judges (12 tracks per audio) and a 10-rank ladder of
voice-cloned candidates. Together they cover the transcript and audio
dimensions the reward model needs to score."

    scope "`6-datasource/anny-render-corpus`"

    decision ~S"""
    Panel is 7 tracks today per RFDs 2179, 2180, 2181 (Whisper,
    gemma-auto, allosaurus-rus drops); RFD 1102 (task catalog) is the
    live source. The 12-track sub-rung below is the as-shipped roster,
    kept for the retraction record.

    Sub-rungs (each a citable OID under this serial):

      .1    12-track ASR panel: parakeet, whisper, voxtral, wav2vec2,
            gemma-auto + gemma-gbnf, voxtral-ipa, ipa-whisper-s/b,
            allosaurus universal/eng/rus. See `emit_10track_panel.py`,
            `add_allosaurus_control.py`.
      .2.1  10 voice clones per audio via Qwen3-TTS-12Hz-1.7B-Base:
            identity, pitch/tempo perturbation gradient, wrong content,
            wrong subject. See `voice_clone_10rank.py`.
      .2.2  Real different-speaker reference for rank9/10 using sub_1
            SpeakingFaces clips with `x_vector_only_mode=True`.
      .3    Score wavlm-cos + voxtral-WER on 150 clones (see
            `score_voice_clones.py`); rescore after .2.2 lands.
      .4    Emit Speech-stub parquets in ETNF three-file form.
      .5    Commit, push, HF upload, PR.

    Panel judges order by canonical-closeness; cloning ranks by
    similarity to reference audio; both feed one MaskScore gradient.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (MaskScore).
    """

    drafted_by :ai
  end
end
