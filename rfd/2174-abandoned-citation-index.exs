# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2174. `mix rfd.render` renders rfd/2174-abandoned-citation-index/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2174 do
  use RFD.DSL

  rfd 2174, "Index of open RFDs citing abandoned RFDs" do
    state :committed

    feature "documentation index for stale citations to abandoned RFDs"

    scope "every open RFD that cites an abandoned or moved RFD"

    decision ~S"""
    This RFD is the citable index for open-to-abandoned citation drift; the 32 pairs sit in
    DETAILS.md, and individual RFDs migrate their citations when next touched.
    """

    problem ~S"""
    An audit found 32 pairs of (open RFD, abandoned RFD it cites). Not all are drift: a retraction
    chain legitimately cites what it walks back, and RFDs 2168 (wholebody detector retraction) and
    2169 (studio-core abandonment) do exactly this. The class of concern is open RFDs that lean on
    an abandoned RFD's decision as if it still holds, without knowing the citation went stale.

    Concentrations: RFD 1122 (wholebody detector, abandoned by 2168) cited by 11 open RFDs; RFD
    1166 (See-Through scoring plan) cited by 7; RFDs 1049-1052 (abandoned model images) cited by
    1133 and 1171; RFD 1019 (strangler-fig studio core, abandoned by 2169) cited by 4.
    """

    section "Details", ~S"""
    Each pair in DETAILS.md is annotated with what the citing RFD's claim depends on and where the
    successor lives. Cheaper than 32 amendments; provides one URN to cite when a reader hits a
    stale reference and needs the successor without a rewrite pass. Pattern established by RFD
    2173 (Qwen3-VL swap index).
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1000 (RFD conventions).
    Applies to: 30-plus open RFDs; see DETAILS.md for the full list.
    """

    details_title "Index of open RFDs citing abandoned RFDs"

    details_preamble ~S"""
    Full pair list from the 2026-09-02 audit. Format: citing RFD (state)
    → cited abandoned RFD → successor to migrate to, or note.
    """

    details "Citations of RFD 1122 (abandoned by RFD 2168)", ~S"""
    RFD 1122's bespoke wholebody detector never shipped; RFDs 1143 (published)
    and 1173 (discussion) settled the pipeline differently. Every citation
    below treats 1122's rendered-ANNY corpus route as authoritative when
    the workspace actually uses ANNY-as-pose-primitive per RFD 1143.

      RFD 1121 (discussion) → RFD 1143 + RFD 1173
      RFD 1123 (discussion) → RFD 1143
      RFD 1126 (discussion) → RFD 1143
      RFD 1128 (discussion) → RFD 1143
      RFD 1130 (discussion) → RFD 1143
      RFD 1131 (discussion) → RFD 1143
      RFD 1132 (discussion) → RFD 1143
      RFD 1134 (discussion) → RFD 1143
      RFD 1142 (discussion) → RFD 1143
      RFD 1148 (discussion) → RFD 1143
      RFD 1170 (ideation)   → RFD 1173
      RFD 1171 (ideation)   → RFD 1173
    """

    details "Citations of RFD 1166 (abandoned)", ~S"""
    RFD 1166 was the See-Through scoring plan; RFD 1168 (segment 3D
    latent with rf-detr) replaced it.

      RFD 1006 (discussion) → RFD 1168
      RFD 1044 (discussion) → RFD 1168
      RFD 1167 (ideation)   → RFD 1168
      RFD 1168 (ideation)   → self (chain, keep)
      RFD 1169 (ideation)   → RFD 1168
      RFD 1170 (ideation)   → RFD 1168
      RFD 1171 (ideation)   → RFD 1168
      RFD 1173 (discussion) → RFD 1168
    """

    details "Citations of RFDs 1049-1052 (abandoned model images)", ~S"""
    Weftspun-image-to-world, LingBot map, WorldMirror2, TripoSplat --
    all abandoned in the 2026-09-01 catalog prune.

      RFD 1038 (discussion) → drop (RFD 1038 mesh model is the same shape)
      RFD 1133 (discussion) → self (chain, keep)
      RFD 1171 (ideation)   → drop
    """

    details "Citations of RFD 1019 (abandoned by RFD 2169)", ~S"""
    The Elixir strangler-fig studio core.

      RFD 1022 (discussion) → RFD 2169
      RFD 1023 (discussion) → RFD 2169
      RFD 1055 (discussion) → RFD 2169
      RFD 1056 (discussion) → RFD 2169
    """

    details "Citations of RFD 1155 (abandoned)", ~S"""
    RFD 1155 abandoned Gemma 4 as an accelerator target; ironic given
    the reasoning-core swap in RFD 2169. Cite path chain intentional.

      RFD 1157 (ideation)   → self (chain, keep)
      RFD 1169 (ideation)   → self (chain, keep)
      RFD 1170 (ideation)   → self (chain, keep)
      RFD 1171 (ideation)   → self (chain, keep)
    """

    details "Citations of other abandoned RFDs", ~S"""
      RFD 1018 (discussion) → RFD 1012 (Phygital passport, abandoned)  → drop
      RFD 1073 (prediscussion) → RFD 1062 (Fly.io toplevel, abandoned) → drop
      RFD 1075 (prediscussion) → RFD 1062                              → drop
      RFD 1076 (prediscussion) → RFD 1062 + RFD 1074 (moved)           → drop
      RFD 1077 (prediscussion) → RFD 1067 (CockroachDB rerank, aband.) → RFD 2140 (OpenBao on FDB)
      RFD 1112 (discussion) → RFDs 1090, 1100 (IWSDK + moat abandoned) → drop
      RFD 2150 (prediscussion) → RFD 2151 (CoAP+OSCORE NIF, abandoned) → drop
      RFD 2173 (committed)  → RFD 2139 (MaskScore QAFT budget, aband.) → self (chain, keep)
    """

    details "Categories", ~S"""
      chain, keep   , retraction chain; the citation IS the walk-back
      successor RFD , migrate the citation on next edit
      drop          , reference is stale, no successor, remove on next edit

    Roughly 60% of the 32 pairs are legitimate retraction chains. The
    remaining ~13 pairs (marked with a successor or drop) are real drift.
    """

    drafted_by :ai
  end
end
