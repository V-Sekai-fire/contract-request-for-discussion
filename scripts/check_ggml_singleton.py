# SPDX-License-Identifier: Apache-2.0 OR MIT
"""One GGML source tree in the workspace (RFD 2188).

Walks the manifest checkout and fails if a `ggml.h` or `src/ggml.c` shows up
outside the canonical path. Vendored llama.cpp is exempt: llama.cpp's own
runtime is the vendor's binary and CLAUDE.md's ggml row exempts it.

    python scripts/check_ggml_singleton.py
    python scripts/check_ggml_singleton.py --self-test
"""
import argparse
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
RFD = HERE.parent
ROOT = next((c for c in [RFD, *RFD.parents] if (c / ".repo").is_dir()), None)

CANONICAL = "2-contract/ggml"

SKIP_DIRS = {".pixi", ".venv", "node_modules", ".git", "build", "dist", "target"}

# llama.cpp bundles ggml as its own source; CLAUDE.md exempts the vendor's
# runtime. A checkout under one of these prefixes is not a rogue copy.
LLAMA_CPP_EXEMPT_PREFIXES = (
    "3-interactor/llama-cpp-npu-vision-upstream/",
    "3-interactor/turboquant-godot/thirdparty/llama_cpp/",
)

SENTINELS = ("ggml.h", "ggml.c")


def is_exempt(rel: str) -> bool:
    if rel.startswith(CANONICAL + "/"):
        return True
    for p in LLAMA_CPP_EXEMPT_PREFIXES:
        if rel.startswith(p):
            return True
    return False


def scan(root: Path) -> list[str]:
    hits = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.name not in SENTINELS:
            continue
        parts = path.relative_to(root).parts
        if any(p in SKIP_DIRS for p in parts):
            continue
        rel = "/".join(parts)
        if is_exempt(rel):
            continue
        hits.append(rel)
    return sorted(hits)


def gate(root: Path) -> int:
    hits = scan(root)
    for h in hits:
        print(f"  FAIL rogue ggml source at {h}")
    print(f"{len(hits)} rogue ggml source files outside {CANONICAL}/ and llama.cpp exemptions.")
    return 1 if hits else 0


def self_test() -> int:
    """Positive control: an empty tree passes. Negative control: a planted ggml.h fails."""
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / ".repo").mkdir()
        (root / CANONICAL).mkdir(parents=True)
        (root / CANONICAL / "ggml.h").write_text("/* canonical */\n")
        assert scan(root) == [], "clean workspace should pass"

        rogue = root / "3-interactor" / "rogue-consumer" / "third_party" / "ggml" / "include"
        rogue.mkdir(parents=True)
        (rogue / "ggml.h").write_text("/* rogue */\n")
        hits = scan(root)
        expected = "3-interactor/rogue-consumer/third_party/ggml/include/ggml.h"
        assert hits == [expected], f"planted rogue not detected: {hits}"

        exempt = root / "3-interactor" / "llama-cpp-npu-vision-upstream" / "ggml" / "include"
        exempt.mkdir(parents=True)
        (exempt / "ggml.h").write_text("/* vendored under llama.cpp */\n")
        hits2 = scan(root)
        assert hits2 == [expected], f"llama.cpp exemption not honoured: {hits2}"

    print("self-test ok: clean passes, rogue fails, llama.cpp exempt.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if ROOT is None:
        print("no .repo/ found; nothing to gate.")
        return 0
    return gate(ROOT)


if __name__ == "__main__":
    sys.exit(main())
