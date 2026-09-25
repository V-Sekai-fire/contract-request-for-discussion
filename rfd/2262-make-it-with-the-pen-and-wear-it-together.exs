# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2262. `mix rfd.render` renders rfd/2262-make-it-with-the-pen-and-wear-it-together/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2262 do
  use RFD.DSL

  rfd 2262, "make it with the pen and wear it together" do
    state :discussion

    flight_level :l3

    feature "A person makes their own character and outfit with the meshing
pen, wears it in V-Sekai's shared world, moves and emotes with others, and
shares it"

    scope "interactor-dress-on, transport-meshing-pen, and the
V-Sekai client and server that host the loop"

    decision ~S"""
    The strategy is a board of vehicles: each is a whole product put in
    front of real people to test one assumption, never a car missing a
    wheel. One card moves at a time; later cards change with what the
    one in motion teaches. The loop is godot-sandbox guest ELFs a host
    loads, with no engine module of its own. OpenUSD is the internal
    format, VRM the one a player shares.
    """

    problem ~S"""
    An anonymous 16-person survey of the shared world's own community
    asked for two things: to create and share what others can see (8),
    and to be with people (8). One asked for emotes; none for rendered
    clips, hair motion or faces.
    """

    related ~S"""
    - RFD 2263 (the Skateboard's simulator gate), the card in motion.
    - RFD 2234 (dress-on pipeline), the loop the vehicles ride on.
    - RFD 1053 (OpenUSD as the internal format).
    - RFD 2229 (interchangeable parts), the rule new parts answer to.
    """

    drafted_by :ai

    details_title "make it with the pen and wear it together"

    details "The vehicles", ~S"""
    Each vehicle names what it tests, who tries it and where it stands.

    - **Bus ticket.** Do people want to make 3D things with a pen in VR,
      and what do they make? The public tried the published CASSIE sketch
      study. Done: people liked it, and wearables exist in what they drew
      (36 study shoes, a dress, two hats).
    - **Skateboard** (earliest testable). Can a person draw an outfit on
      an avatar and get back a garment that fits and drapes? The simulator
      first, a replayed sketch; then one person at a time on a standalone
      VR headset. In motion (RFD 2263).
    - **Scooter.** Will people save, share and wear what they made where
      others see it? The same creators and whoever they share with, phones
      included. Next: save as OpenUSD, export VRM, wear it in the world.
    - **Bicycle** (earliest usable). Will creators use it for their own
      avatar? Early adopters from the survey. Later: their own body (ANNY
      fitted in a guest, or their own mesh), rigged, delivered as VRM.
    - **Motorcycle** (earliest lovable). Will people show it to friends?
      Anyone. Later: the character in parts (body, head, hair), and more
      emotes and dances.
    - **Car.** Only if people ask for it. Later: faces and hair motion;
      nobody in the survey asked.

    Enabling work (CI, the drape's precision, comfort settings against
    motion sickness, the org's rules) is not a vehicle; it runs as the
    card in motion needs it.
    """

    details "Where it runs", ~S"""
    The first host is `transport-meshing-pen`: the xr-grid pen with the
    dress-on ELFs inserted through godot-sandbox. It has two
    implementations, chosen per process through the OpenXR runtime
    manifest (`XR_RUNTIME_JSON`):

    - the simulator, OXRSys with a replayed hand, repeatable on a desk
      and in CI;
    - a standalone VR headset on a Linux-based OS, a person holding the
      pen.

    Later hosts are the shared world's client and a dedicated server
    running the same ELFs, for people on phones and anyone who would
    rather not wait; the server hands back the VRM.
    """

    details "Formats", ~S"""
    - OpenUSD is internal: Pixal3D's answer, the loop's meshes and
      materials, and a person's strokes (one linear `BasisCurves` prim
      per stroke, the boundary mark a per-curve primvar).
    - VRM is delivery: what a player loads and shares.
    """
  end
end
