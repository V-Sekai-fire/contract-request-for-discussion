# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# `mix rfd.plan` renders fourloops-plan.usda from this file; the layer is a
# build artifact (RFD 2232, extended to the apparatus plans).
defmodule Plan.FourloopsPlan do
  use RFD.Plan

  plan "FourloopsPlan" do
    meta(metersPerUnit: 1, upAxis: "Z", defaultPrim: "FourLoops")

    string("plan", "fourloops")
    int_list("sizePoints", [
      1,
      2,
      3,
      5,
      8
    ])
    string_list("sizeVocabulary", [
      "XS",
      "S",
      "M",
      "L",
      "XL"
    ])
    string_list("sources", [
      "7-service/livebook/priv/python/weft_loop.py",
      "6-datasource/anny-render-corpus/score_edits.py",
      "6-datasource/anny-render-corpus/gen_posed_from_reference.py",
      "6-datasource/anny-render-corpus/render_view.py",
      "3-interactor/pose-consensus/python/soma_referee.py",
      "3-interactor/voxhammer-image-mesh-editing/server.py",
      "3-interactor/pixal3d-image-to-textured-mesh/server.py",
      "CLAUDE.md",
      "rfd/1144-image-to-omnigen2/DETAILS.md",
      "rfd/1147-what-editscore-costs-and-returns/DETAILS.md"
    ])
    string("state", "build")
    string_list("stateVocabulary", [
      "exists",
      "build",
      "measure",
      "stub",
      "blocked"
    ])

    scope("FourLoops", [
      scope("Quantities", [
        attr("cocoKeypoints", "int", 17),
        attr("annyKeypointAssetPoints", "int", 23),
        attr("basemeshVertices", "int", 19158),
        attr("hammersleyViews", "int", 8),
        attr("editscorePeakGib512", "float", 6.75),
        attr("editscorePeakGib1024", "float", 8.6),
        attr("editscoreMaxPixels", "int", 262144),
        attr("omnigen2WeightsGib", "int", 17),
        attr("deskVramGib", "int", 24),
        attr("voxhammerPlanSteps", "int", 7),
        attr("refereeImpossibleResidual", "float", 0.02),
        attr("refereeHandResidual", "float", 0.006),
        attr("refereeChainGrowthLimit", "float", 1.6),
        attr("editscoreScaleMax", "float", 1.0e1),
        attr("editscoreMatchingOverall", "float", 4.29),
        attr("editscoreNonsenseOverall", "float", 0.0),
        attr("omnigen2WeightsGibBf16", "float", 14.75),
        attr("omnigen2PeakGibBf16", "float", 17.14),
        attr("omnigen2WeightsGibNf4", "float", 4.33),
        attr("omnigen2PeakGibNf4", "float", 6.72),
        attr("ugen300BudgetGb", "int", 8)
      ]),
      scope("Stages", [
        prim("Keypoints", [
          attr("kind", "token", "detector", [uniform: true]),
          attr("state", "token", "blocked", [uniform: true]),
          attr("blocker", "token", "environment", [uniform: true]),
          attr("blockedOn", "string[]", [
            "rfdetr"
          ]),
          attr("entry", "string", "3-interactor/rf-detr-cpp, reached through Godot once Godot is exposed to MCP"),
          attr("outputs", "string", "17 joints, pixels and confidence")
        ]),
        prim("AnnyFit", [
          attr("kind", "token", "fit", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "7-service/livebook/priv/python/loop1_fit.py:fit_2d"),
          attr("outputs", "string", "pose, keypoints2d, residual_px, stature_px, camera"),
          attr("roundTripMedianPx", "float", 1.56),
          attr("roundTripPctOfStature", "float", 0.263),
          attr("retracted", "bool", true),
          attr("retractedState", "token", "blocked", [uniform: true]),
          attr("vertexOnlySolvers", "string[]", [
            "anny.AnnyInverter",
            "soma.PoseInversion"
          ])
        ]),
        prim("Render", [
          attr("kind", "token", "render", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "6-datasource/anny-render-corpus/render_view.py"),
          attr("outputs", "string", "png and json sidecar")
        ]),
        prim("EditScore", [
          attr("kind", "token", "scorer", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "editscore.EditScore.evaluate"),
          attr("base", "string", "Qwen/Qwen3-VL-8B-Instruct"),
          attr("adapter", "string", "EditScore/EditScore-Qwen3-VL-8B-Instruct"),
          attr("precision", "string", "nf4"),
          attr("precisionNote", "string", "Quantisation is permitted for a verifier and forbidden for a generator. This is a verifier.")
        ]),
        prim("OmniGen2", [
          attr("kind", "token", "generator", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "6-datasource/anny-render-corpus/omnigen2_edit.py"),
          attr("environment", "string", "pixi -e omnigen2")
        ]),
        prim("CycleGan", [
          attr("kind", "token", "generator", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "3-interactor/cyclegan-style-transfer/server.py:/predict")
        ]),
        prim("Pixal3D", [
          attr("kind", "token", "generator", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "3-interactor/pixal3d-image-to-textured-mesh/server.py"),
          attr("outputs", "string", "state, views, cameras, then glb and layer")
        ]),
        prim("VoxHammer", [
          attr("kind", "token", "editor", [uniform: true]),
          attr("state", "token", "stub", [uniform: true]),
          attr("wired", "bool", false),
          attr("blockedOn", "string[]", [
            "not-implemented",
            "takes-mesh-not-latent",
            "usd-layer-not-renderable"
          ]),
          attr("entry", "string", "3-interactor/voxhammer-image-mesh-editing/server.py:/predict"),
          attr("inputs", "string", "mesh, reference, region, seed")
        ]),
        prim("Referee", [
          attr("kind", "token", "gate", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          attr("entry", "string", "3-interactor/pose-consensus/python/soma_referee.py:referee"),
          attr("verdicts", "string[]", [
            "FITS",
            "IMPOSSIBLE",
            "HANDS_UNTRUSTED",
            "NOT_RUN"
          ])
        ]),
        prim("Harness", [
          attr("kind", "token", "harness", [uniform: true]),
          attr("state", "token", "measure", [uniform: true]),
          attr("entry", "string", "7-service/livebook/priv/python/weft_loop.py"),
          attr("controls", "string", "7-service/livebook/priv/python/test_weft_loop.py")
        ])
      ]),
      scope("Loops", [
        prim("L1KeypointsToAnny", [
          attr("order", "int", 1),
          attr("size", "token", "L", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          attr("artifact", "string", "render png"),
          attr("hazard", "string", "The detector emits 17 joints and the render asset emits 23. The comparison takes an explicit subset or it compares different things."),
          rel("driver", "/FourLoops/Stages/Harness"),
          rel("propose", [
            "/FourLoops/Stages/Keypoints",
            "/FourLoops/Stages/AnnyFit",
            "/FourLoops/Stages/Render"
          ]),
          rel("score", [
            "/FourLoops/Stages/EditScore",
            "/FourLoops/Stages/Referee"
          ]),
          rel("repair", "/FourLoops/Stages/AnnyFit")
        ]),
        prim("L2ImageToOmniGen2", [
          attr("order", "int", 2),
          attr("size", "token", "M", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          attr("artifact", "string", "edited png"),
          attr("hazard", "string", "The instruction comes from a text input rather than a filename, because a filename that matches no key is skipped without a word."),
          rel("driver", "/FourLoops/Stages/Harness"),
          rel("propose", "/FourLoops/Stages/OmniGen2"),
          rel("score", "/FourLoops/Stages/EditScore"),
          rel("repair", "/FourLoops/Stages/OmniGen2")
        ]),
        prim("L3StylizedToOmniGen2", [
          attr("order", "int", 3),
          attr("size", "token", "M", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          attr("artifact", "string", "edited png"),
          attr("hazard", "string", "Anything derived from val2017 inherits the holdout. A stylized set built from it is evaluation only, twice over."),
          rel("driver", "/FourLoops/Stages/Harness"),
          rel("propose", [
            "/FourLoops/Stages/CycleGan",
            "/FourLoops/Stages/OmniGen2"
          ]),
          rel("score", "/FourLoops/Stages/EditScore"),
          rel("repair", "/FourLoops/Stages/OmniGen2")
        ]),
        prim("L4LatentToPixal3D", [
          attr("order", "int", 4),
          attr("size", "token", "XL", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          attr("artifact", "string", "latent state, then views, then glb"),
          attr("routerStatistic", "token", "spread-over-mean", [uniform: true]),
          attr("spreadSelectsLatent", "float", 0.15),
          attr("routerCalibrated", "bool", false),
          attr("hazard", "string", "VoxHammer raises NotImplementedError outside stub mode, and it takes a mesh rather than the latent, so the arm passes through /extract first."),
          rel("driver", "/FourLoops/Stages/Harness"),
          rel("propose", "/FourLoops/Stages/Pixal3D"),
          rel("score", "/FourLoops/Stages/EditScore"),
          rel("repair", [
            "/FourLoops/Stages/VoxHammer",
            "/FourLoops/Stages/OmniGen2"
          ])
        ])
      ]),
      scope("Tasks", [
        prim("T01Harness", [
          attr("order", "int", 1),
          attr("size", "token", "M", [uniform: true]),
          attr("state", "token", "exists", [uniform: true]),
          rel("produces", "/FourLoops/Stages/Harness")
        ]),
        prim("T02Notebook2", [
          attr("order", "int", 2),
          attr("size", "token", "M", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T01Harness"),
          rel("realizes", "/FourLoops/Loops/L2ImageToOmniGen2")
        ]),
        prim("T03Notebook3", [
          attr("order", "int", 3),
          attr("size", "token", "S", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T02Notebook2"),
          rel("realizes", "/FourLoops/Loops/L3StylizedToOmniGen2")
        ]),
        prim("T04Notebook1", [
          attr("order", "int", 4),
          attr("size", "token", "L", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T01Harness"),
          rel("realizes", "/FourLoops/Loops/L1KeypointsToAnny")
        ]),
        prim("T05Notebook4", [
          attr("order", "int", 5),
          attr("size", "token", "L", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T01Harness"),
          rel("realizes", "/FourLoops/Loops/L4LatentToPixal3D")
        ]),
        prim("T06Serve", [
          attr("order", "int", 6),
          attr("size", "token", "XS", [uniform: true]),
          attr("state", "token", "build", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T01Harness")
        ]),
        prim("T07WireVoxHammer", [
          attr("order", "int", 7),
          attr("size", "token", "XL", [uniform: true]),
          attr("state", "token", "blocked", [uniform: true]),
          rel("needs", "/FourLoops/Tasks/T05Notebook4"),
          rel("produces", "/FourLoops/Stages/VoxHammer")
        ])
      ])
    ])

  end
end
