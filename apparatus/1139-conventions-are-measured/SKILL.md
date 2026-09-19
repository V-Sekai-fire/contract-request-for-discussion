---
name: rig-conventions-and-sidedness
description: Measure scale, up, forward and handedness off a rig before using it, and check that the body's right stays the body's right through every conversion. Use before rendering a subject, after any export or axis change, and whenever a fit or a label mapping is written.
---

# Checking a rig's conventions

The result is four measurements and a refusal, not a look at a render.
Every check here exists because its absence produced a result that
looked correct.

## Order

1. **Measure up.** The longest rest extent, and it must beat the next
   axis by a clear margin. ANNY reads Z at 1.59 times the next. A rig
   whose declared up disagrees with its geometry is refused.
2. **Measure scale.** Stature along that axis, in metres. Outside 1.2
   to 2.3 is a units error rather than an unusual body: 165.972 m is
   centimetres read as metres.
3. **Measure forward from the chest**, the normal to the shoulder line,
   which is where the ribs point. Report the gaze and the feet beside
   it. On an unposed rig all three agree; ANNY reads 270 degrees with
   0.0 disagreement.
4. **Measure handedness three ways.** Signed mesh volume, the joint
   basis determinants, and the `.R` against `.L` split on the right
   axis. ANNY reads +0.05120, +1.000000 across all 104, and +0.300
   against -0.300.
5. **Check sidedness across the mapping.** Every keypoint named `left_`
   or `right_` must sit on the side its name claims. All 22 of the
   regressor's sided points do.
6. **Run it before the render, not after.** `render_grid.py` calls the
   check first. Ninety-six frames take a minute and the check takes
   milliseconds.
7. **Re-run after any conversion.** npz to USD, rig to render, ANNY
   `.R` to COCO `right_`, kusudama to MuJoCo. A conversion is where a
   convention is lost.

## Traps

**A left-right swap survives every other check.** It reprojects onto
the same pixels, reports the same residual and passes the referee,
because those measure reprojection. It also survives the chest test,
since the chest normal mirrors with the body. Drive it with the swap
itself: exchange `left_` and `right_` in the label list and require
that all 22 land on the wrong side.

**The `.R` against `.L` split cannot catch a mirror alone.** `right` is
built from the chest, the chest mirrors, so `.R` lands positive again.
A mirrored rig declared posed passed until signed volume and the basis
determinants were added. Those two do not mirror away.

**The feet are not the forward witness on a posed rig.** A stance can
plant the feet away from the chest. The hv_1 fit had the chest and gaze
agreeing to 2.8 degrees and the feet 55.3 degrees off, and using the
feet put every camera phrase 55 degrees wrong. That subject and the
hv_2 one were deleted on 2026-08-25 as invalid poses, so the numbers
here are the record and the sets are not on disk.

**A hip-width witness is degenerate here.** `pelvis.L` and `pelvis.R`
both sit at the origin, separation 0.0, because the hips are the local
root. The cross product is zero and the azimuth reads 0, which looks
like an answer.

**The phrase is about the subject, while the camera is placed in world
azimuth.** They are the same number only for a rig facing world zero.
ANNY faces 270, and without that offset every frame the grid called a
front view was a profile.

**An unrun check is reported, never skipped.** Without the joints only
up and scale can be measured, so the run says which two did not run.

**No 180 degree correction is needed for this rig, and the render is
how you know.** A front view places the camera in front of the chest
and shows the face. If a sign were inverted the same frame would show
the back.

## An ordering is a convention, and two orderings will differ

Rule 6 is usually read as up axis, units and rotation order. It also
covers **the order of a labelled array**, and that one is quieter.

ANNY's `coco.pth` stores its six foot points as

    left_big_toe, right_big_toe, left_small_toe, right_small_toe,
    left_heel, right_heel

COCO-WholeBody's indices 17 to 22 are

    left_big_toe, left_small_toe, left_heel,
    right_big_toe, right_small_toe, right_heel

Position 18 is `right_big_toe` in one and `left_small_toe` in the other.
Copying that tensor by slice puts four of six feet on the wrong point
and **nothing raises**: the shapes agree, the weights still sum to one,
and the defect appears only as a body whose feet are crossed.

So copy by name, and check the orders still differ. A check that only
copies by name is silent if the orders ever converge, and a check that
asserts they differ tells you when the workaround stopped being needed.
The published order came from mmpose's own dataset config, not from
memory, because a wire format recalled is a wire format guessed.

## A vertex index means nothing without its mesh

ANNY's two topologies share **zero** vertices: 19,158 for
`base_mesh="makehuman"` against 13,718 for the body topology.
`coco.pth`'s weight vectors are 19,158 wide, and
`anny_rig.build_corpus_model()` returns 13,718 while
`loop1_fit.build_model()` returns 19,158.

Multiplying one by the other does not fail loudly. It fails at a vertex
index, which is why the corpus schema carries `topology_id` as a foreign
key rather than a label: a label can be forgotten and a foreign key
fails the validator. Any file that stores vertex indices records the
topology beside them, and any check on such a file asserts the widths
match before it does anything else.
