# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2118. `mix rfd.render` renders rfd/2118-a-baker-replaces-the-godot-editor/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2118 do
  use RFD.DSL

  rfd 2118, "A baker replaces the godot editor" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    | Step | Mechanism | Available in a template | | ------ |
    ----------------------------------------------------------------- |
    ----------------------- | | Import | `editor/import/*`, writing
    `res://.godot/imported/` | No | | Export | `--export-release`,
    `--export-debug`, implemented under `editor/` | No |
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "A baker replaces the godot editor"

    details "What requires the editor today", ~S"""
    | Step   | Mechanism                                                         | Available in a template |
    | ------ | ----------------------------------------------------------------- | ----------------------- |
    | Import | `editor/import/*`, writing `res://.godot/imported/`               | No                      |
    | Export | `--export-release`, `--export-debug`, implemented under `editor/` | No                      |

    Everything else a client does at runtime is already outside `editor/`.
    `ResourceFormatLoaderText` reads `.tscn`,
    `GLTFDocument` reads glTF, and the Basis transcoder reads supercompressed textures. All three
    compile into
    `target=template_release`.
    """

    details "Why the mount is a module", ~S"""
    `PackedData` accepts additional backends through `PackSource`, which is how the `.pck` reader
    and the ZIP reader are
    both registered. A third source resolving `res://` against a directory or a chunk store is the
    same shape of object.

    The registration has to happen at core initialization. A GDExtension library loads after the
    filesystem is already
    serving, which is late enough that boot resources have been requested and failed. A module
    registered at
    `MODULE_INITIALIZATION_LEVEL_CORE` is in place before the first request.

    The usual argument against a module is that it costs an engine rebuild. `godot-images` already
    builds the engine for
    every platform on every run, so that cost is already paid.
    """

    details "Three ways this fails quietly", ~S"""
    `#ifdef TOOLS_ENABLED` around the registration. `template_release` strips the define, so the
    block disappears: the
    module compiles, the template links, and `res://` resolves to nothing with no diagnostic
    naming the cause.

    An unstable `uid://`. Godot 4 `.tscn` refers to external resources by UID. A baker that
    generates a fresh UID per run
    produces scenes whose references break on the second bake. Emitting plain `res://` paths
    avoids the class of bug
    entirely.

    A reference to an importable file. `res://foo.png` inside a baked `.tscn` reintroduces the
    import step for one asset
    and takes the editor back with it. Every external reference has to name a runtime-loadable
    file or live inside the
    glTF.
    """

    details "What is already true", ~S"""
    - `entities-godot` carries `modules/basis_universal` and `modules/gltf`.
    - `godot-images` has no `module_*_enabled=no` on any platform, so both are in every artifact
    it publishes.
    - `zone-client-godot` builds `scons platform=web target=template_release` and ships
    `bin/godot.web.template_release.*`
      with no editor involved.
    - `godot-images` now releases `windows-template-release.zip` and `linux-template-release.zip`
    alone. The editors still
      build, and `build-docker` still publishes `godot-editor-double` from that target.
    """

    details "Alternatives considered", ~S"""
    Keep the editor headless in CI. This works today and is what happens now. It keeps a 482 MB
    GUI binary in the
    pipeline to perform a step whose inputs the baker already holds, and it keeps import as a
    build stage that content
    delivered at runtime never passes through.

    Commit `res://.godot/imported/`. This removes the import step from CI by moving its output
    into version control. The
    artifacts are engine-version-specific and binary, so an engine bump invalidates all of them at
    once, and review sees
    no meaningful diff.

    Pre-pack with a third-party `.pck` writer. The format is documented and writers exist. This
    solves export without
    solving import, so the editor stays for textures and meshes. It remains the fallback if the
    pack source proves harder
    than expected.

    Emit binary `.scn` instead of `.tscn`. Loading is faster. The binary format's compatibility
    across engine versions is
    a weaker contract for a baker to hold than the text format's, and the parse cost is paid once
    per scene load against
    a network fetch that costs more.
    """

    details "Consequences", ~S"""
    The pipeline becomes scons for the template, the baker for the content, the module for the
    mount, and the sandbox for
    the logic. No step needs a GUI, and no step needs a machine with the editor installed.

    The module is the new failure surface. Three ways it fails quietly are recorded in
    `DETAILS.md`, and the first one
    compiles, links, and resolves nothing.
    """

    details "Open question", ~S"""
    Whether a release template boots an unpacked project directory or requires a `.pck`. The
    module answers this by
    construction once it exists. Until it does, the question is unsettled and a short experiment
    against
    `linux-template-release` would settle it.
    """

    drafted_by :ai
  end
end
