# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2240. `mix rfd.render` renders rfd/2240-citation-metadata-and-review-interchange/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2240 do
  use RFD.DSL

  rfd 2240,
      "One citation, one metadata serialization, one vector pair, one intermediate, one review timeline" do
    state :discussion

    feature "how a deliverable is stored and reviewed: the citation record as the master, its XMP serialization in a sidecar beside every asset, SVG and Lottie for vector, CineForm for the intermediate, OpenTimelineIO for the review timeline"

    scope "every repository that ships a deliverable; `2-contract/manuals-weftspun` (the converter and its gate), the three CineForm repositories, and the `CITATION.cff` beside every placed project"

    decision ~S"""
    `CITATION.cff` stays the master attribution record and every other metadata
    artefact is derived from it. The machine serialization is ISO 16684-1 (XMP)
    as RDF/XML, in a sidecar named for the asset's own stem, so a clip, a
    drawing or an animation carries its title, authors, licence and identifier
    wherever it travels. Static vector is W3C SVG, animated vector is Lottie
    under its IANA type `video/lottie+json` with the extension `.lot`, the
    intermediate is CineForm, and a review timeline is OpenTimelineIO with
    OpenColorIO naming the display. The converter is Elixir. `DETAILS.md`
    carries the mapping matrix, the precedence rules, and the two places this
    workspace differs from the specification as it arrived.
    """

    problem ~S"""
    The workspace already required a `.cff` beside a deliverable and already
    encoded intermediates as CineForm, but nothing said how a citation reaches
    the asset a reviewer opens. A `.cff` beside a clip is separated from it the
    first time either is copied, and no editor or player reads YAML attribution.
    Review timelines had no interchange, the vector formats were used without
    being named, and the same citation was retyped by hand.
    """

    references ~S"""
    - Citation File Format 1.2.0, and ISO 16684-1:2012, the XMP data model and its RDF/XML serialization
    - W3C SVG 1.1 and 2.0; Lottie under IANA `video/lottie+json`
    - SMPTE VC-5, the CineForm intra-frame wavelet codec, and RFD 1123 which chose its SDK
    - Academy Software Foundation OpenTimelineIO and OpenColorIO 2
    """

    related ~S"""
    RFD 1123 (CineForm in Godot, which chose the SDK over FFmpeg on licence), RFD 1137 (encoding a frame set, the pair that does the work), RFD 2166 (the maskscore CineForm bundle), RFD 2239 (a row's artefacts are columns, and each modality's format), RFD 2232 (documents rendered from a source, not hand-written).
    """

    details_title "One citation, one metadata serialization, one vector pair, one intermediate, one review timeline"

    details "The stack", ~S"""
    | layer | standard | in this workspace |
    | --- | --- | --- |
    | attribution record | Citation File Format 1.2.0 | `CITATION.cff`, one per placed project and one per deliverable |
    | metadata serialization | ISO 16684-1:2012 (XMP), RDF/XML | `<stem>.xmp` beside the asset; `CITATION.xmp` at a project root |
    | static vector | W3C SVG 1.1 / 2.0 | `.svg`, which may also carry the packet inline |
    | animated vector | Lottie, IANA `video/lottie+json` | `.lot` with a mandatory sidecar |
    | intermediate video | CineForm (SMPTE VC-5), intra-frame | `interactor-cineform` writing Matroska |
    | review timeline | OpenTimelineIO | `.otio` under `review/` |
    | display transform | OpenColorIO 2 | the configuration named by the timeline |

    Every layer is an open standard with a permissive implementation the
    workspace can link. That is the same argument RFD 1123 made when it chose
    the CineForm SDK, which is `Apache-2.0 OR MIT`, over an LGPL alternative
    that a single-binary export cannot relink.
    """

    details "Where a file goes", ~S"""
        project_root/
        |-- CITATION.cff                     the master record, hand-written
        |-- CITATION.xmp                     derived from it, never hand-written
        |-- review/
        |   |-- sequence_101_review.otio     the cut list, markers and annotation tracks
        |   `-- sequence_101_review.ocio     the display configuration
        `-- assets/
            |-- video/
            |   |-- shot_010_comp.mkv        the CineForm intermediate
            |   `-- shot_010_comp.xmp        its sidecar
            `-- annotations/
                |-- shot_010_draw.svg        static markup
                |-- shot_010_draw.xmp
                |-- shot_010_anim.lot        animated markup
                `-- shot_010_anim.xmp

    **Stem parity.** A sidecar shares its asset's stem exactly and adds `.xmp`.
    Nothing else names a sidecar, and `CITATION.xmp` is the one file named for
    the record rather than for an asset.

    **Precedence.** The `.cff` is the authority and every `.xmp` is derived from
    it, so a disagreement is a stale derivation and not a decision to be made.
    An SVG may carry its packet inline for standalone rendering, and the sidecar
    still wins at ingest, so one reader does not see one story and another a
    different one. A `.lot` never carries RDF: a Lottie player wants strictly
    formed JSON, and the sidecar is mandatory there for that reason. A CineForm
    file is left alone; its extended metadata resolves through the sidecar.
    """

    details "The mapping, CFF 1.2.0 to ISO 16684-1", ~S"""
    Namespaces: `dc:` Dublin Core, `xmp:` XMP Basic, `xmpRights:` Rights
    Management, `prism:` PRISM Basic, `xmpDM:` Dynamic Media, and `cff:` for the
    two fields no standard namespace carries.

    | CFF field | XMP property | RDF structure |
    | --- | --- | --- |
    | `cff-version` | `cff:schemaVersion` | plain literal |
    | `title` | `dc:title` | `rdf:Alt` with `xml:lang="x-default"` |
    | `message` or `abstract` | `dc:description` | `rdf:Alt` with `xml:lang="x-default"` |
    | `version` | `prism:version` and `xmp:Identifier` | plain literal |
    | `date-released` | `xmp:CreateDate` and `dc:date` | `rdf:Seq` |
    | `authors` | `dc:creator` | `rdf:Seq`, order preserved |
    | `license` | `dc:rights` and `xmpRights:Marked` | `rdf:Alt`, and `True` |
    | `doi` | `prism:doi` and `dc:identifier` | plain literal, `doi:` prefixed |
    | `repository-code` or `url` | `prism:url` and `dc:relation` | plain literal |
    | `keywords` | `dc:subject` | `rdf:Bag` |
    | `commit` | `cff:commit` | plain literal |

    An author with `name` is taken as written; one with `given-names` and
    `family-names` is joined in that order. `dc:format` carries the asset's
    media type, which is `video/lottie+json` for a `.lot`, `image/svg+xml` for
    an `.svg`, and the container's type for a clip. A media sidecar adds
    `xmpDM:videoFrameRate` and `xmpDM:duration`, which is what lets a timeline
    marker and an animation agree on a frame.

    The packet is wrapped in the standard `xpacket` markers so a reader that
    scans a file for one finds it.
    """

    details "Where this differs from the specification as it arrived", ~S"""
    Two differences, both because an existing decision already carries an
    argument.

    **The container is Matroska, not QuickTime.** The specification wraps
    CineForm in `.mov`. RFD 1123 chose Matroska and recorded why: AVI's 32-bit
    size field stops a file at 4 GiB, about 56 seconds of 4K60 at these
    bitrates, and MOV performed the same as Matroska while being less open.
    `interactor-cineform` writes Matroska today, with a `V_MS/VFW/FOURCC` video
    track carrying `CFHD` and an uncompressed PCM audio track. A specification
    that named the container differently does not undo a measurement, so the
    container stays Matroska and the sidecar rule is unchanged: the stem is the
    stem whatever the extension.

    **The converter is Elixir, not Python.** The workspace's rule is that new
    scripting is Elixir and that a reader parses rather than matches text. The
    specification's reference implementation builds RDF with an XML tree, which
    is the right shape; it is transcribed rather than adopted. A Python file
    that survives in this workspace is a runner wrapping a model and says so in
    its first line, which a metadata converter is not.

    FFmpeg is blocklisted and now carries the row that says so. RFD 1175 had
    asserted the ban since it was written while no row backed it; the operator
    confirmed it on 2026-09-08 and the row and its argument landed in the same
    change as this document. The argument is the licence: FFmpeg is
    LGPL-2.1-or-later, what this workspace ships is one statically linked
    binary per platform, and the relinking the licence asks for is a thing that
    binary cannot offer. Capability was never the question, since FFmpeg does
    hold a CineForm encoder.
    """

    details "What is built and what is not", ~S"""
    Read on this desk, 2026-09-08:

    | piece | state |
    | --- | --- |
    | `interactor-cineform` | source complete, **its own manifest root**; `contract-bus`, QCBOR, `cineform-sdk` and `libwebm` placed by it. Not compiled here |
    | `transport-cineform-tui` | source complete, a manifest root of its own, the job sender over the bus |
    | `service-cineform` | composes the two so one `contract-bus` is checked out rather than two, and states which pin wins where they disagree |
    | the engine-side writer | `modules/cineform` on the fork's `cineform-movie-writer` branch: `movie_writer_cineform.cpp`, `video_stream_cineform.cpp`, the class reference and a demo, with `thirdparty/cineform` and `thirdparty/libwebm` vendored on that branch. The branch is not merged into the working branch the manifest names |
    | Lottie, written | already here and older than this document: `scripts/keypoint_render.py` writes an animation, `scripts/lottie.schema.json` is the 1.0 schema vendored with its provenance, and `scripts/check_lottie_spec.py` validates against it and caught 207 errors when first run |
    | Lottie, read | ThorVG is vendored in the fork at `thirdparty/thorvg` with only the SVG and raster loaders; the loader sources are not in the placed tree, and a branch of the fork carries the re-vendoring unmerged. Upstream 1.0.3 is now placed at `2-contract/thorvg` with the loader intact |
    | OpenColorIO | a build option of the OpenUSD source vendored under `datasource-flow`, not built here |
    | cmake and ninja | **present and running**: cmake 4.4.3 and ninja 1.13.2 from the `datasource-flow` and `voxhammer.cpp` environments. Neither is on the default `PATH`, which is what an earlier reading of mine mistook for absence |
    | FFmpeg | blocklisted, and now with the row that says so. Not installed and not on `PATH`, but two runnable copies sit in package caches; the one that runs is a GPL build and does hold a `cfhd` encoder, which is why the row argues licence rather than capability |

    Four of those rows correct an earlier claim of mine, and the pattern behind
    every one is the same: I probed a `PATH` or a single manifest and reported
    a filesystem fact. The engine-side writer is not an unplaced repository;
    RFD 1123 recorded that the separate repository was created, used and
    deleted and that the module shipped inside the fork, and the fork is
    placed. cmake and ninja run here. Lottie is not a new format for this
    workspace at all: a writer, a vendored schema and a validator predate this
    document, and this document's contribution is to say that the extension
    that validator already demands is the one the workspace uses.

    That gate had never run. Nothing invoked it, its `jsonschema` dependency
    was declared nowhere, and the writer kept emitting `.json` while the gate
    refused anything but `.lot`, so the rename it was written to force never
    happened. The dependency is pinned and the writer renamed in the same
    change as this document.
    """

    details "The gates", ~S"""
    - `mix cff.xmp <in.cff> <out.xmp>` derives a sidecar; `--check` derives into
      memory and refuses when the file on disk differs, which is how a stale
      sidecar is caught rather than trusted.
    - Every field in the matrix has a round-trip test: a record carrying it
      produces the property, and a record without it produces no empty element.
    - Controls: a `.cff` that is not a mapping is refused by shape; an author
      with neither `name` nor `family-names` is refused with the entry named; a
      planted stale sidecar fails `--check`; a `.lot` carrying an RDF packet is
      refused; an asset with no sidecar is reported, counted and never skipped.
    - The anti-entropy pass gains the pair "asset against its sidecar", with one
      planted sidecar-less asset reporting exactly one more.
    - A clip's sidecar states the frame rate and duration, and the timeline
      marker that names the clip must agree; a planted disagreement fails.
    """

    drafted_by :ai
  end
end
