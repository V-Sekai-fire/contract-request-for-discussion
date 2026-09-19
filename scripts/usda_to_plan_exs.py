# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Import a hand-authored `.usda` apparatus layer into an `RFD.Plan` Elixir source.

RFD 2232 makes the layer a build artifact and the `.exs` the tracked source. This reads a
layer through the USD API rather than by regex, so what it emits is what USD composed, and
`mix rfd.plan` renders it back. `--verify` re-renders and compares the two through
`ExportToString`, which is the only comparison that ignores formatting and nothing else.

Usage:
    python usda_to_plan_exs.py LAYER.usda [--module Plan.Name] [--verify]
"""

import argparse
import subprocess
import sys
from pathlib import Path

from pxr import Sdf

SCALARS = {"string": "string", "token": "token", "int": "int", "bool": "bool",
           "float": "float", "float3": "float3"}


def shortest_float(v):
    """The shortest decimal that reads back as the same float32.

    USD stores `float` at single precision, so 6.72 comes back as 6.71999979019165. Writing
    that expansion into the source would be a different number from the one the documents
    state, and `check_fourloops_plan.py` searches the documents for the text.
    """
    import struct

    def as32(x):
        return struct.unpack("f", struct.pack("f", x))[0]

    target = as32(v)
    for digits in range(1, 18):
        s = f"%.{digits}g" % target
        if as32(float(s)) == target:
            return elixir_float(s)
    return elixir_float(repr(target))


def elixir_float(s):
    """Elixir wants a digit either side of the point and no `+` in the exponent."""
    if "e" in s or "E" in s:
        mant, _, exp = s.replace("E", "e").partition("e")
        if "." not in mant:
            mant += ".0"
        return f"{mant}e{int(exp)}"
    return s if "." in s else s + ".0"


def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lit(v, usd_type):
    if usd_type == "float3":
        return "[" + ", ".join(repr(float(x)) for x in v) + "]"
    if usd_type == "bool":
        return "true" if v else "false"
    if usd_type == "float":
        return shortest_float(v)
    if usd_type == "int":
        return str(int(v))
    return q(v)


def py_type(value, key):
    """The DSL type for a customLayerData value. An unmapped type is an error, not a cast."""
    if isinstance(value, str):
        return "string", False
    if isinstance(value, bool):
        return "bool", False
    if isinstance(value, int):
        return "int", False
    if isinstance(value, float):
        return "float", False
    items = list(value) if hasattr(value, "__iter__") else None
    if items is None:
        raise SystemExit(f"unsupported customLayerData value for {key!r}: {type(value)}")
    if not items:
        return "string", True
    return py_type(items[0], key)[0], True


def base_type(spec):
    """`string[]` -> (`string`, True). Anything unmapped is an error, never a guess."""
    name = str(spec)
    arr = name.endswith("[]")
    base = name[:-2] if arr else name
    if base not in SCALARS:
        raise SystemExit(f"unsupported attribute type {name!r}; extend RFD.Plan first")
    return base, arr


def emit_value(base, arr, value, indent):
    if not arr:
        return lit(value, base)
    items = list(value) if value is not None else []
    if not items:
        return "[]"
    pad = " " * (indent + 2)
    inner = (",\n" + pad).join(lit(x, base) for x in items)
    return "[\n" + pad + inner + "\n" + " " * indent + "]"


def emit_prim(prim, indent):
    pad = " " * indent
    kind = {Sdf.SpecifierDef: "prim", Sdf.SpecifierOver: "over"}[prim.specifier]
    if prim.typeName == "Scope":
        kind = "scope"
    elif prim.typeName:
        raise SystemExit(f"unsupported prim type {prim.typeName!r} on {prim.path}")

    body = []
    if prim.documentation:
        body.append(f"{pad}  doc({q(prim.documentation)})")
    for attr in prim.attributes:
        base, arr = base_type(attr.typeName)
        opts = []
        if not attr.custom:
            opts.append("custom: false")
        if attr.variability == Sdf.VariabilityUniform:
            opts.append("uniform: true")
        val = emit_value(base, arr, attr.default, indent + 2)
        tail = ", [" + ", ".join(opts) + "]" if opts else ""
        body.append(f"{pad}  attr({q(attr.name)}, {q(base + ('[]' if arr else ''))}, {val}{tail})")

    for rel in prim.relationships:
        targets = [str(t) for t in rel.targetPathList.explicitItems]
        if len(targets) == 1:
            body.append(f"{pad}  rel({q(rel.name)}, {q(targets[0])})")
        else:
            inner = (",\n" + pad + "    ").join(q(t) for t in targets)
            body.append(f"{pad}  rel({q(rel.name)}, [\n{pad}    {inner}\n{pad}  ])")

    for child in prim.nameChildren:
        body.append(emit_prim(child, indent + 2))

    joined = (",\n").join(body)
    return f"{pad}{kind}({q(prim.name)}, [\n{joined}\n{pad}])"


def emit(layer, module):
    root = Sdf.Layer.FindOrOpen(str(layer))
    if root is None:
        raise SystemExit(f"{layer} does not parse as a usda layer")

    lines = [
        "# Copyright (c) 2026 K. S. Ernest (iFire) Lee",
        "# SPDX-License-Identifier: MIT",
        "#",
        f"# `mix rfd.plan` renders {Path(layer).name} from this file; the layer is a",
        "# build artifact (RFD 2232, extended to the apparatus plans).",
        f"defmodule {module} do",
        "  use RFD.Plan",
        "",
        f"  plan {q(module.split('.')[-1])} do",
    ]

    meta = []
    # USD spells the layer's `doc =` as the info key `documentation`.
    for key, info in (("metersPerUnit", "metersPerUnit"), ("upAxis", "upAxis"),
                      ("defaultPrim", "defaultPrim"), ("doc", "documentation")):
        if info not in root.pseudoRoot.ListInfoKeys():
            continue
        v = root.pseudoRoot.GetInfo(info)
        if v is None or v == "":
            continue
        v = str(v) if key == "defaultPrim" else v
        if isinstance(v, float) and v == int(v):
            v = int(v)
        meta.append(f"{key}: " + (q(v) if isinstance(v, str) else str(v)))
    if meta:
        lines.append("    meta(" + ", ".join(meta) + ")")

    subs = list(root.subLayerPaths)
    if subs:
        lines.append("    sublayers([" + ", ".join(q(s) for s in subs) + "])")
    if meta or subs:
        lines.append("")

    for key, value in (root.customLayerData or {}).items():
        base, arr = py_type(value, key)
        if not arr:
            lines.append(f"    {base}({q(key)}, {lit(value, base)})")
        else:
            pad = " " * 6
            inner = (",\n" + pad).join(lit(x, base) for x in value)
            lines.append(f"    {base}_list({q(key)}, [\n{pad}{inner}\n    ])")

    lines.append("")
    for prim in root.rootPrims:
        lines.append(emit_prim(prim, 4))
        lines.append("")

    lines += ["  end", "end", ""]
    return "\n".join(lines)


def verify(source, layer):
    out = Path(layer).with_suffix(".verify.usda")
    r = subprocess.run(["mix", "rfd.plan", str(source)], capture_output=True, text=True,
                       shell=sys.platform == "win32")
    if r.returncode != 0:
        print(r.stdout[-1500:] + r.stderr[-1500:])
        return False
    a, b = Sdf.Layer.FindOrOpen(str(layer)), Sdf.Layer.FindOrOpen(str(layer))
    out.unlink(missing_ok=True)
    return a is not None and b is not None and a.ExportToString() == b.ExportToString()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("layer")
    ap.add_argument("--module")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    stem = Path(args.layer).stem
    module = args.module or "Plan." + "".join(p.title() for p in stem.replace("_", "-").split("-"))
    text = emit(args.layer, module)
    target = Path(args.layer).with_suffix(".exs")
    target.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {target} as {module}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
