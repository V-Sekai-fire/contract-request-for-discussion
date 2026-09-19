# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Checks each model folder's Docker image.

RFD 1036 gives the rules. This script covers the ones a reader
forgets, and it leaves the rest to `docker build`.

A broken server.py fails when a rented GPU starts it, which is money
away from the edit that broke it. These checks run at commit time.
"""

import ast
import json
import sys
from pathlib import Path

# RFD 1036. Neither this box's own worker nor vast.ai runs a health
# probe of its own, thus a caller polls /health until ready.
REQUIRED_ROUTES = ["/health", "/predict"]


def check_server(path: Path) -> list[str]:
    problems = []
    source = path.read_text(encoding="utf-8")

    try:
        ast.parse(source)
    except SyntaxError as error:
        return [f"does not parse: line {error.lineno}: {error.msg}"]

    for route in REQUIRED_ROUTES:
        if f'"{route}"' not in source:
            problems.append(f"serves no {route}, which RFD 1036 requires")

    # The contract stage runs with no GPU and no weights. Without this
    # switch the image cannot be tested anywhere but a rented card.
    if "WEFTSPUN_STUB" not in source:
        problems.append("reads no WEFTSPUN_STUB, thus the contract cannot be tested")

    return problems


def check_dockerfile(path: Path) -> list[str]:
    problems = []
    source = path.read_text(encoding="utf-8")

    if "AS contract" not in source:
        problems.append("has no contract stage, which RFD 1036 requires")

    if "AS worker" not in source:
        problems.append("has no worker stage")

    # Cog is gone. RFD 1036 records why.
    if "cog.yaml" in source or "runpod" in source.lower():
        problems.append("names Cog or RunPod, and RFD 1036 selects plain Docker instead")

    return problems


def check_input(path: Path) -> list[str]:
    try:
        body = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"does not parse: {error}"]

    # An HTTP body is the request. A RunPod-shaped {"input": ...}
    # wrapper makes every field missing, and the server answers 422.
    if isinstance(body, dict) and set(body) == {"input"}:
        return ['wraps the body in "input", which no HTTP route reads']

    return []


CHECKS = {
    "server.py": check_server,
    "Dockerfile": check_dockerfile,
    "test_input.json": check_input,
}


def is_model_folder(path: Path) -> bool:
    """A model folder is one with a server.py in it. RFD 1036's rules are about the
    thing that serves the model, and a probe's Dockerfile is not that."""
    return (path.parent / "server.py").is_file()


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv]

    if not paths:
        for name in CHECKS:
            paths += sorted(Path(".").glob(f"*/{name}"))

    failed = 0
    checked = 0
    skipped = []
    for path in paths:
        check = CHECKS.get(path.name)
        if not check:
            continue

        if not is_model_folder(path):
            skipped.append(path)
            continue

        checked += 1
        for problem in check(path):
            failed = 1
            print(f"FAIL {path} {problem}", file=sys.stderr)

    for path in skipped:
        print(f"skip {path}: no server.py beside it, thus not a model folder")

    if not failed:
        print(f"ok {checked} model image file(s), {len(skipped)} skipped")
    return failed


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
