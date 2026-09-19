# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Every manifest project's README.md tagline is <= 144 characters.

The tagline is the first prose paragraph, which is what a reader sees before
scrolling. A repo tagline is small on purpose: it forces the writer to pick what
the project is, not to hedge. 144 characters is the budget.

THE FIRST LINE IS NOT THE TAGLINE. This gate read it for a long time, and in 118
of 127 READMEs that line is the `# Title` heading. A title is always short, so
the gate passed on every one of them without ever reading the sentence it claims
to bound. Badge rows are skipped for the same reason: a row of shields.io links
is not a sentence either.

Silently skips projects with no README.md; reports the count so the skip does
not read as a pass (CLAUDE.md rule 3). Matches the pattern of check_anti_entropy's
existing "every README <= 40 lines" check over RFDs.

    python scripts/check_project_readme_length.py
    python scripts/check_project_readme_length.py --self-test
"""
import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import md_ast

HERE = Path(__file__).resolve().parent
RFD = HERE.parent
ROOT = next((c for c in [RFD, *RFD.parents] if (c / ".repo").is_dir()), None)
LIMIT = 144

# A fork's tagline is upstream's prose, not ours to bound. Read from the git remote
# rather than a list somebody has to remember to grow, which is the test
# check_commit_style.py already uses to pick a commit convention.
#
# The taglines that were already over the budget when the measurement was corrected.
# New and edited READMEs are held to it; these are not, until someone rewrites them.
GRANDFATHERED = {
    ".claude",
    ".vscode",
    "1-transport/cineform-tui",
    "1-transport/usd-viewer",
    "2-contract/bus",
    "2-contract/lean-deform-exact",
    "2-contract/swing-twist-kusudama",
    "2-contract/trellis2-mesh-vae-slang",
    "3-interactor/anny",
    "3-interactor/bumblebee",
    "3-interactor/cyclegan-style-transfer",
    "3-interactor/editscore",
    "3-interactor/kimodo-text-to-motion",
    "3-interactor/mitsuba3",
    "3-interactor/moge-upstream",
    "3-interactor/mujoco-mjx",
    "3-interactor/nx-ggml",
    "3-interactor/omnigen2",
    "3-interactor/physics",
    "3-interactor/pixal3d-ggml",
    "3-interactor/pixal3d-image-mesh-painting",
    "3-interactor/pixal3d-image-to-textured-mesh",
    "3-interactor/pose-consensus",
    "3-interactor/residual-fsq-recommender",
    "3-interactor/rf-detr-ggml",
    "3-interactor/sinew-mount-drift",
    "3-interactor/sinew-solve",
    "3-interactor/skin-tokens-ggml",
    "3-interactor/skintokens-auto-rig",
    "3-interactor/soma-x",
    "3-interactor/stable-diffusion-ggml/thirdparty/libwebp",
    "3-interactor/trellis2-ex",
    "3-interactor/trellis2-image-mesh-painting",
    "3-interactor/trellis2-image-to-textured-mesh",
    "3-interactor/tris-to-quads",
    "3-interactor/tropes-removal-model",
    "3-interactor/turboquant-godot",
    "3-interactor/udon2godot",
    "3-interactor/ufbx-to-openusd",
    "3-interactor/unified-modal-embedder",
    "3-interactor/voxhammer-image-mesh-editing",
    "3-interactor/voxhammer-text-mesh-editing",
    "3-interactor/wan-vace-upstream",
    "4-entities/godot",
    "4-entities/godot-cassie",
    "4-entities/godot-demo-projects",
    "4-entities/godot-image-diffusion",
    "4-entities/godot-language-model",
    "4-entities/godot-motion-bricks",
    "4-entities/godot-oit",
    "4-entities/godot-rf-detr",
    "4-entities/godot-rfd-2251-fire",
    "4-entities/godot-spatial-audio",
    "4-entities/godot-witness",
    "4-entities/humanoid-rom",
    "5-repository/usd-core-wheels",
    "6-datasource/anny-render-corpus",
    "6-datasource/foundationdb",
    "6-datasource/rf-detr-keypoint-data",
    "6-datasource/rf-detr-segmentation-data",
    "6-datasource/store",
    "6-datasource/thebasemesh-stage",
    "6-datasource/versitygw-local",
    "7-service/bao-sqlite-fdb",
    "7-service/cineform",
    "7-service/cineform/thirdparty/cineform-sdk",
    "7-service/cineform/thirdparty/iceoryx2",
    "7-service/crossbuild-fedora",
    "7-service/godot-build"
}


def tagline(text: str) -> str:
    """The first paragraph with prose in it, badges and bare links skipped."""
    for para in md_ast.paragraphs(text):
        stripped = para
        while True:
            once = re.sub(r"!?\[[^\]\[]*\]\([^)]*\)", "", stripped)
            if once == stripped:
                break
            stripped = once
        stripped = re.sub(r"<[^>]+>", "", stripped)
        if len(re.sub(r"[^A-Za-z0-9 ]", "", stripped).strip()) >= 20:
            return " ".join(para.split())
    return ""


def is_fork(project: Path) -> bool:
    done = subprocess.run(
        ["git", "-C", str(project), "remote", "-v"],
        capture_output=True, text=True,
    )
    return "V-Sekai-fire" not in done.stdout


def gate(root: Path) -> int:
    man = ET.parse(root / ".repo/manifests/default.xml").getroot()
    projects = [(p.get("name"), p.get("path")) for p in man.iter("project")]
    have, missing, exempt, over = [], [], [], []
    for _name, path in projects:
        if path in GRANDFATHERED or is_fork(root / path):
            exempt.append(path)
            continue
        rd = root / path / "README.md"
        if not rd.is_file():
            missing.append(path)
            continue
        have.append(path)
        line = tagline(rd.read_text(encoding="utf-8", errors="replace"))
        if len(line) > LIMIT:
            over.append((path, len(line)))
    for path, ln in over:
        print(f"  FAIL {path}/README.md  tagline {ln} chars > {LIMIT}")
    print(f"  {len(have)} projects with README.md, {len(missing)} without, {len(exempt)} forks or grandfathered.")
    print(f"{len(over)} of {len(have)} taglines over {LIMIT} chars.")
    return 1 if over else 0


def self_test() -> int:
    long_line = "x" * 200
    controls = [
        ("a title heading is not the tagline", "# short\n\n" + long_line, False),
        ("the tagline under the budget", "# t\n\nA short sentence about the project.", True),
        ("exactly 144", "# t\n\n" + "x" * 144, True),
        ("145", "# t\n\n" + "x" * 145, False),
        ("a badge row is skipped for the sentence under it",
         "# t\n\n[![b](https://img.shields.io/x)](https://example.invalid)\n\n" + long_line, False),
        ("a badge row alone leaves no tagline",
         "# t\n\n[![b](https://img.shields.io/x)](https://example.invalid)\n", True),
        ("a fenced block is not a tagline", "# t\n\n```\n" + long_line + "\n```\n", True),
        ("no prose at all", "# t\n", True),
    ]
    fails = 0
    for label, text, expected_pass in controls:
        got = len(tagline(text)) <= LIMIT
        if got != expected_pass:
            print(f"  FAIL {label}: got {'pass' if got else 'fail'}, expected {'pass' if expected_pass else 'fail'}")
            fails += 1
    if fails:
        print(f"{fails} of {len(controls)} controls failed")
        return 1
    print(f"ok   {len(controls)} of {len(controls)} controls fired in both directions")
    return 0


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if ROOT is None:
        print("no .repo above this checkout, so there is no workspace to check")
        return 0
    return gate(ROOT)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
