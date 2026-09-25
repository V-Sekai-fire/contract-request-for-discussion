# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1151. `mix rfd.render` renders rfd/1151-which-axes-the-survey-weights/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1151 do
  use RFD.DSL

  rfd 1151, "Which axes the survey weights" do
    state :discussion

    feature "allocating corpus and clip time across axes"

    scope "`6-datasource/anny-render-corpus/render_mtoon_frames.py`,
`placeholder_cards.py`, `CORPUS_DESIGN.md`"

    attest_in :none

    decision ~S"""
    Persona species is weighted by the survey, because the survey measures
    it: humanoid 50, semi-humanoid 38, robot 6, animal 2, plant 2, other 1,
    monster 0 per cent.

    Skin tone stays uniform, as a decision rather than a default. No
    published mapping from residence to Monk exists, and running the survey
    through one built for the purpose put Monk 10 at 0.19 per cent, two
    frames of 900, which is where the defect is largest.

    Every category carries a floor of 1.5 seconds, including one measured
    at zero, and axes with no data get a card naming them, so a clip cannot
    imply coverage it does not have.
    """

    problem ~S"""
    A sweep across an axis has to allocate time or samples somehow.
    "Uniform" and "by population" make different claims, so choosing by
    taste makes a claim without saying so.

    The Nem x Mila Social VR Lifestyle Survey, n=1,012, measures avatar
    species directly. It does not measure skin tone. It measures residence,
    and its sample is 73.3 per cent Japan.
    """

    references ~S"""
    - `DETAILS.md` carries the allocation and the six cards.
    """

    related ~S"""
    RFD 1150 gives the tone ladder. RFD 1141 sends artifacts.
    """

    details_title "Which axes the survey weights"

    details "What the survey measures, and what it does not", ~S"""
    Q2-1, avatar species, n=1,012: humanoid 50, semi-humanoid 38, robot or cyborg 6, animal 2,
    plant 2, other 1, monster 0 per cent. Measured directly.

    Q1-1, residence: Japan 73.3, North America 14.1, Europe 6.0, Asia except Japan 5.1, Oceania
    0.7, South America 0.3, Africa 0.2, Middle East 0.1, Russia 0.1 per cent. The slide states a
    sampling error of 4 to 14 per cent at maximum, and Africa is n=2 while the Middle East and
    Russia are n=1 each.

    The deck asks about skin tone nowhere.
    """

    details "Why tone stays clear of that weighting", ~S"""
    Run through a region-to-tone table built for the purpose, the survey gives Monk 10 about 0.19
    per cent, which is two frames of 900. That is the tone where the flat multiplier is weakest,
    dE 4.83 against 17.28, so population weighting hands the worst case the least screen time.

    That table came from nowhere citable. The Monk scale publishes colour rather than demography,
    and the one global-looking distribution in the literature is a study of skin-tone EMOJI on
    Twitter in five bins, measuring selection behaviour on one platform.

    The survey also finds 66 per cent prefer an avatar unlike their physical selves, so avatar
    appearance is chosen rather than inherited, which leaves a user demographic describing the
    wrong population.
    """

    details "The floor, and the minimum honest length", ~S"""
    Every category gets 90 frames, 1.5 seconds, the same hold the tone ladder uses because that
    is the duration shown to read. A category measured at zero still gets it: monster is 0 per
    cent of 1,012 and a category rounded off the screen cannot be looked at to see whether it is
    handled.

    Seven personas at that floor is 10.5 seconds before any weighting applies:

    | clip | floor share | humanoid : monster |
    | ---: | ---: | ---: |
    | 15 s | 70% | 2.5 : 1 |
    | 22 s | 47% | 5.0 : 1 |
    | 30 s | 35% | 7.6 : 1 |

    At fifteen seconds a 50 per cent share and a 0 per cent share differ by 2.5x, so the clip
    would look survey-weighted while being mostly floor. The floor therefore sets a minimum
    length below which the weighting is a claim the picture does not support.
    """

    details "The cards", ~S"""
    Six, one per axis with no data: persona species with no avatar assets, skin tone by
    population with no citable distribution, the test split at 0 records, identities at 1 of
    23,000, global illumination unimplemented, and subsurface and outline assets unused.

    They are derived from one `GAPS` tuple, and a control asserts every gap appears in the
    sequence. A gap added to `CORPUS_DESIGN.md` without a card, or a card with no gap behind it,
    fails rather than passing quietly.
    """

    details "Left unmeasured", ~S"""
    Whether the persona weighting is right, because it cannot be rendered: the axis needs six
    species of avatar asset and this repository has one human body and 1,254 CC0 objects.
    """

    drafted_by :ai
  end
end
