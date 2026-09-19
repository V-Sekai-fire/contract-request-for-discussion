#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Typed asset-prefix naming.

Assets under 5-repository and 6-datasource carry a typed prefix that
names their kind (T_ texture, DA_ data asset, SM_/SK_ mesh, S_ sound,
etc.) followed by an underscore and a PascalCase name.

    python scripts/check_asset_prefix.py --self-test          # control
    python scripts/check_asset_prefix.py --base <ref>         # actual (gate on diff)
    python scripts/check_asset_prefix.py                      # scouts (report tree)
    python scripts/check_asset_prefix.py <paths...>           # actual (gate on paths)

The prefix set matches the widely-adopted UE5 asset style guide from
Allar; the workspace uses it because it collapses to one convention
across image, mesh, sound and data assets rather than one per format.
"""
from __future__ import annotations
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def workspace_root() -> str:
    d = ROOT
    while d != os.path.dirname(d):
        if os.path.isdir(os.path.join(d, ".repo")):
            return d
        d = os.path.dirname(d)
    return ROOT

PREFIXES = {
    "T", "DA",
    "SM", "SK",
    "A", "AS", "AC",
    "M", "MI", "MF", "MPC",
    "S", "SC",
    "VFX", "PS",
    "BP", "EUW", "WBP",
    "F",
}

ASSET_EXT = {
    ".png", ".jpg", ".jpeg", ".webp", ".exr", ".bmp", ".tif", ".tiff",
    ".json", ".yaml", ".yml", ".toml",
    ".glb", ".gltf", ".fbx", ".obj", ".stl", ".ply", ".usdz", ".usdc",
    ".wav", ".ogg", ".mp3", ".flac",
}

SCOPED_ROOTS = ("6-datasource/", "5-repository/")

SKIP_NAMES = {
    "README.md", "CITATION.cff", "LICENSE", "NOTICE",
    "pixi.lock", "pixi.toml", ".gitattributes", ".gitignore",
    "manifest.json", "mix.lock", "mix.exs", "package.json", "package-lock.json",
    "pyproject.toml", "poetry.lock", "Cargo.toml", "Cargo.lock",
    "Makefile", "CMakeLists.txt", "tsconfig.json", "compile_commands.json",
    ".DS_Store",
    "config.json", "adapter_config.json", "tokenizer.json", "tokenizer_config.json",
    "special_tokens_map.json", "generation_config.json", "training_args.json",
    "preprocessor_config.json", "processor_config.json", "chat_template.jinja",
    "vocab.json", "merges.txt",
}

SKIP_DIR_TOKENS = {
    ".git", ".pixi", ".lake", "_build", "deps", "node_modules",
    "build", "dist", ".venv", "__pycache__", ".repo",
    "thirdparty", "third_party", "vendor",
}

NAME_RX = re.compile(r"^([A-Z]+)_([A-Z][A-Za-z0-9]*(?:_[A-Z0-9][A-Za-z0-9]*)*)$")


def in_scope(path: str) -> bool:
    p = path.replace("\\", "/")
    if not p.startswith(SCOPED_ROOTS):
        return False
    name = os.path.basename(p)
    if name in SKIP_NAMES:
        return False
    ext = os.path.splitext(name)[1].lower()
    if ext not in ASSET_EXT:
        return False
    for tok in SKIP_DIR_TOKENS:
        if f"/{tok}/" in "/" + p:
            return False
    return True


def name_violates(name: str) -> str | None:
    stem = os.path.splitext(name)[0]
    m = NAME_RX.match(stem)
    if not m:
        return "shape (want <PREFIX>_PascalCase, e.g. T_Az000_A)"
    if m.group(1) not in PREFIXES:
        return f"prefix {m.group(1)!r} not in Allar set"
    return None


def gate(paths):
    fails = 0
    for p in paths:
        if not in_scope(p):
            continue
        why = name_violates(os.path.basename(p))
        if why:
            print(f"  FAIL {p}  {why}")
            fails += 1
        else:
            print(f"  ok   {p}")
    return 1 if fails else 0


def gate_diff(base: str) -> int:
    out = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AR", f"{base}...HEAD"],
        capture_output=True, text=True, cwd=ROOT, check=True,
    )
    paths = [p for p in out.stdout.splitlines() if p]
    scoped = [p for p in paths if in_scope(p)]
    if not scoped:
        print(f"0 in-scope asset(s) added or renamed since {base}.")
        return 0
    return gate(scoped)


def report() -> int:
    ws = workspace_root()
    fails = 0
    scanned = 0
    for root in SCOPED_ROOTS:
        base = os.path.join(ws, root)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_TOKENS]
            for name in filenames:
                rel = os.path.relpath(os.path.join(dirpath, name), ws)
                if not in_scope(rel):
                    continue
                scanned += 1
                why = name_violates(name)
                if why:
                    print(f"  {rel}  {why}")
                    fails += 1
    print(f"scouts: {fails} violation(s) across {scanned} asset(s) in scope.")
    return 0


def self_test() -> int:
    ok_cases = [
        "T_Az000_A.png", "T_Msl256_00.png", "T_Baseline_Msl1024_00.png",
        "DA_Ladder.json", "DA_AzimuthRecoveryA.json",
        "SM_AnnyHead_LOD0.glb", "S_ClickTick_01.wav", "M_Skin_Base.json",
    ]
    bad_cases = [
        ("az000_A.png", "no prefix"),
        ("t_az000_A.png", "lowercase prefix"),
        ("T_az000_A.png", "lowercase after prefix"),
        ("T-Az000-A.png", "hyphens not underscores"),
        ("XYZ_Foo_A.png", "prefix not in Allar set"),
        ("Az000_A.png", "no underscore-terminated prefix"),
    ]
    fails = 0
    for good in ok_cases:
        why = name_violates(good)
        if why:
            print(f"  FAIL positive control {good!r}: got {why}")
            fails += 1
    for bad, label in bad_cases:
        why = name_violates(bad)
        if not why:
            print(f"  FAIL negative control {bad!r} ({label}): passed but should not have")
            fails += 1
    total = len(ok_cases) + len(bad_cases)
    if fails:
        print(f"{fails} of {total} controls failed")
        return 1
    print(f"ok   {total} of {total} controls fired in both directions")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true", help="control: planted good + planted broken")
    ap.add_argument("--base", help="actual: gate files added or renamed since <ref>")
    ap.add_argument("paths", nargs="*", help="actual: gate these paths")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if a.base:
        return gate_diff(a.base)
    if a.paths:
        return gate(a.paths)
    return report()


if __name__ == "__main__":
    sys.exit(main())
