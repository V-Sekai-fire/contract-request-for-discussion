#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Check the serial register against the tree, and against its own last revision.

RFD 1000 gives the rule. A serial is allocated once, and it names one document
for as long as the arc under the PEN exists. This gate is what makes that
enforceable rather than agreed.

The register is `SERIALS.usda`, in Essential Tuple Normal Form: one typed array
per column, parallel by index, no nulls and nothing derivable stored. A count
is `len()` of a column rather than a number somebody maintains beside it. USD
type-checks the arrays on read, which a markdown table cannot do.

This site's register holds this site's serials and no other site's. A site that
copied another's rows would be a second record of the same fact, and the first
one to be edited would win by accident. `pen-66606.usda`
composes the sites into one view with sublayers, which is USD doing the join
rather than a human doing the copy.

The second check is the one that matters. A renumbering removes serials from
the register and adds others in their place, so it fails on the removals. A
retitle keeps the serial and changes the slug, so it passes. The difference
between the two is the whole point of the register.

Run --self-test to see each check reject a known-bad input, because a check
that passes on broken input certifies the defect instead of catching it.
"""
import os
import re
import subprocess
import sys

from pxr import Sdf, Usd

ORG = "1"
REGISTER = "SERIALS.usda"
DIR_RE = re.compile(r"^(1[0-9]{3})-([a-z0-9-]+)$")
RFD_ROOT = "rfd"


ROW_RE = re.compile(r"^S(\d+)$")


def table_rows(prim, names):
    """Rows of one relation, in whichever of the two shapes the layer uses.

    ROW FORM is one prim per tuple, the primary key in the prim name. USD refuses
    two siblings with one name, so a duplicate key cannot be authored and there is
    no second array to fall out of step with the first.

    ARRAY FORM is parallel `int[]`/`string[]`, which is what this register held
    until the row form replaced it and what other sites still author. It is read
    because `pen-66606.usda` sublayers those registers, and a reader that
    understood only the new shape would compose them to nothing -- which reads
    exactly like a site with no serials.
    """
    children = [(m.group(1), c) for c in prim.GetChildren()
                if (m := ROW_RE.match(c.GetName()))]
    if children:
        other = [n for n in names if n != "serial"]
        rows = []
        for key, child in children:
            value = key
            for name in other:
                a = child.GetAttribute(name)
                if a and a.HasAuthoredValue():
                    value = a.Get()
            rows.append((int(key), value))
        return rows

    arrays = {}
    for name in names:
        a = prim.GetAttribute(name)
        arrays[name] = list(a.Get()) if a and a.HasAuthoredValue() else None
    if arrays.get("serial") is None:
        return []
    other = "slug" if "slug" in names else "recorded_in"
    values = arrays.get(other)
    if values is None or len(values) != len(arrays["serial"]):
        return []
    return list(zip(arrays["serial"], values))


def read(text):
    """(allocated, deleted) as serial -> value, read off the composed stage.

    A relation is any prim declaring `columns`, and the scope above it says
    which table it is. Reading the declaration rather than a fixed prim path
    means a site can name its own scope after itself.
    """
    layer = Sdf.Layer.CreateAnonymous(".usda")
    if not layer.ImportFromString(text):
        raise ValueError(f"{REGISTER} does not parse as USD")
    stage = Usd.Stage.Open(layer)
    allocated, deleted = {}, {}
    for prim in stage.Traverse():
        cols = prim.GetAttribute("columns")
        if not (cols and cols.HasAuthoredValue()):
            continue
        names = [str(c).split()[0] for c in cols.Get() if str(c).strip()]
        table = None
        for ancestor in str(prim.GetPath()).split("/"):
            if ancestor == "Allocated":
                table = allocated
            elif ancestor == "Deleted":
                table = deleted
        if table is None:
            continue
        for serial, value in table_rows(prim, names):
            table[f"{serial}"] = str(value)
    return allocated, deleted


def rows_are_well_formed(text):
    """Every declared column is carried, in whichever shape the relation uses.

    ROW FORM: each `S<serial>` prim authors every declared column except the
    primary key, which is its name. A missing value is named rather than skipped.

    ARRAY FORM: every column authors an array and the arrays are equal length.
    THAT CHECK IS THE REASON THIS FUNCTION EXISTS. `read()` used to `zip()` the
    columns, and `zip` stops at the shorter one, so a register that lost a slug
    would report one fewer serial and no error at all -- a silent truncation that
    reads exactly like a smaller register. The row form cannot fail that way,
    which is why this register moved to it; the check stays for the sites that
    have not.
    """
    problems = []
    layer = Sdf.Layer.CreateAnonymous(".usda")
    if not layer.ImportFromString(text):
        return [f"{REGISTER} does not parse as USD"]
    stage = Usd.Stage.Open(layer)
    for prim in stage.Traverse():
        cols = prim.GetAttribute("columns")
        if not (cols and cols.HasAuthoredValue()):
            continue
        names = [str(c).split()[0] for c in cols.Get() if str(c).strip()]
        other = [n for n in names if n != "serial"]
        children = [c for c in prim.GetChildren() if ROW_RE.match(c.GetName())]

        if children:
            for child in children:
                for name in other:
                    a = child.GetAttribute(name)
                    if not (a and a.HasAuthoredValue()):
                        problems.append(
                            f"{child.GetPath()} declares column {name} and authors no value")
            continue

        lengths = {}
        for name in names:
            a = prim.GetAttribute(name)
            if not (a and a.HasAuthoredValue()):
                problems.append(f"{prim.GetPath()} declares column {name} and authors no array")
                continue
            lengths[name] = len(a.Get())
        if len(set(lengths.values())) > 1:
            shown = ", ".join(f"{n} {c}" for n, c in sorted(lengths.items()))
            problems.append(f"{prim.GetPath()} column arrays are not parallel: {shown}")
    return problems


def rfd_dirs(root):
    return sorted(
        d for d in os.listdir(os.path.join(root, "rfd"))
        if os.path.isdir(os.path.join(root, "rfd", d)) and DIR_RE.match(d)
    )


def check_tree(root, text):
    problems = rows_are_well_formed(text)
    allocated, deleted = read(text)
    if not allocated:
        # An empty register would make every check below vacuous, which reads
        # exactly like a pass.
        problems.append(f"{REGISTER} lists no allocated serial, which is never correct here")

    for serial in sorted(set(allocated) & set(deleted)):
        problems.append(f"serial {serial} is listed as allocated and as deleted")

    for serial in sorted(set(allocated) | set(deleted)):
        if serial[0] != ORG:
            problems.append(f"serial {serial}: this site is {ORG}, and that serial is not its own")

    on_disk = {}
    for d in rfd_dirs(root):
        m = DIR_RE.match(d)
        on_disk[m.group(1)] = m.group(2)

    for serial, slug in sorted(on_disk.items()):
        if serial not in allocated:
            problems.append(f"{serial}-{slug}: the directory has no row in {REGISTER}")
        elif allocated[serial] != slug:
            problems.append(
                f"{serial}: {REGISTER} says {allocated[serial]}, the directory says {slug}"
            )

    for serial in sorted(allocated):
        if serial not in on_disk:
            problems.append(f"serial {serial} is allocated and has no directory")

    for serial in sorted(deleted):
        if serial in on_disk:
            problems.append(f"serial {serial} is listed as deleted and has a directory")

    return problems


def check_against_base(base_text, text):
    """A serial the previous revision recorded is still recorded, and unmoved.

    Allocated to deleted is the one move a serial may make. The reverse would
    hand a retired number to a new document, which is a renumbering wearing a
    deletion for a hat.
    """
    problems = []
    was_a, was_d = read(base_text)
    now_a, now_d = read(text)
    now = set(now_a) | set(now_d)

    for serial in sorted(set(was_a) | set(was_d)):
        if serial not in now:
            problems.append(f"serial {serial} was in the register and is gone from it")
    for serial in sorted(was_d):
        if serial in now_a:
            problems.append(f"serial {serial} was deleted and is allocated again")
    return problems


SOURCE = "SERIALS.exs"


def base_register(root, base):
    """The register at `base`: the rendered layer if that revision tracked it, else
    the `SERIALS.exs` source rendered through `mix rfd.usda` (RFD 2232)."""
    r = subprocess.run(
        ["git", "show", f"{base}:{REGISTER}"],
        cwd=root, capture_output=True, text=True,
    )
    if r.returncode == 0:
        return r.stdout
    r = subprocess.run(
        ["git", "show", f"{base}:{SOURCE}"],
        cwd=root, capture_output=True, text=True,
    )
    if r.returncode != 0:
        return None
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".exs", delete=False, encoding="utf-8") as fh:
        fh.write(r.stdout)
    r = subprocess.run(
        ["mix", "rfd.usda", fh.name],
        cwd=root, capture_output=True, text=True, shell=os.name == "nt",
    )
    os.unlink(fh.name)
    if r.returncode != 0:
        raise SystemExit(f"mix rfd.usda failed on {base}:{SOURCE}:\n{r.stdout}{r.stderr}")
    return r.stdout


def register_is_new(root, base):
    """True when this change is the one that adds the register.

    The change that introduces the register has no previous revision to be held
    against, and it is the only change that may say so. Every later one has a
    base register, and a missing base then means the file was deleted, which is
    how a renumbering would get past this gate if it could.
    """
    r = subprocess.run(
        ["git", "diff", "--name-status", f"{base}...HEAD", "--", REGISTER, SOURCE],
        cwd=root, capture_output=True, text=True,
    )
    return r.returncode == 0 and r.stdout.strip().startswith("A")


GOOD = """#usda 1.0
(
    defaultPrim = "Serials"
)

def Scope "Serials"
{
    def Scope "Weftspun"
    {
        def Scope "Allocated"
        {
            def "Rfd"
            {
                custom string[] columns = ["serial int16 PK", "slug string"]
                custom int[] serial = [1000, 1001]
                custom string[] slug = ["conventions", "a-slug"]
            }
        }

        def Scope "Deleted"
        {
            def "Retired"
            {
                custom string[] columns = ["serial int16 PK", "recorded_in int16 FK"]
                custom int[] serial = [1002]
                custom int[] recorded_in = [1070]
            }
        }
    }
}
"""


def self_test():
    import shutil
    import tempfile

    ragged = GOOD.replace('custom string[] slug = ["conventions", "a-slug"]',
                          'custom string[] slug = ["conventions"]')
    unauthored = GOOD.replace('custom string[] slug = ["conventions", "a-slug"]', "")
    empty = GOOD.replace("custom int[] serial = [1000, 1001]", "custom int[] serial = []").replace(
        'custom string[] slug = ["conventions", "a-slug"]', "custom string[] slug = []")
    foreign = GOOD.replace("custom int[] serial = [1000, 1001]", "custom int[] serial = [1000, 2001]")
    renumbered = GOOD.replace("custom int[] serial = [1000, 1001]", "custom int[] serial = [1000, 1003]").replace(
        "1001-a-slug", "1003-a-slug")
    revived = GOOD.replace("custom int[] serial = [1002]", "custom int[] serial = []").replace(
        "custom int[] recorded_in = [1070]", "custom int[] recorded_in = []").replace(
        "custom int[] serial = [1000, 1001]", "custom int[] serial = [1000, 1001, 1002]").replace(
        'custom string[] slug = ["conventions", "a-slug"]',
        'custom string[] slug = ["conventions", "a-slug", "a-new-thing"]')

    def build(tmp, dirs, text):
        for d in dirs:
            os.makedirs(os.path.join(tmp, "rfd", d))
        with open(os.path.join(tmp, REGISTER), "w", encoding="utf-8") as fh:
            fh.write(text)

    both = ["1000-conventions", "1001-a-slug"]
    tree_cases = [
        ("a register that matches the tree", both, GOOD, False),
        ("a directory with no row", both + ["1004-extra"], GOOD, True),
        ("a row with no directory", ["1000-conventions"], GOOD, True),
        ("a slug that disagrees with the directory",
         ["1000-conventions", "1001-another-slug"], GOOD, True),
        ("a deleted serial with a directory", both + ["1002-back-again"], GOOD, True),
        ("column arrays that are not parallel", both, ragged, True),
        ("a declared column with no array", both, unauthored, True),
        ("an empty register", ["1000-conventions"], empty, True),
        ("a serial belonging to another site", both, foreign, True),
    ]
    base_cases = [
        ("an appended serial", GOOD, GOOD.replace(
            "custom int[] serial = [1000, 1001]", "custom int[] serial = [1000, 1001, 1005]").replace(
            'custom string[] slug = ["conventions", "a-slug"]',
            'custom string[] slug = ["conventions", "a-slug", "a-later-one"]'), False),
        ("a retitled slug", GOOD, GOOD.replace("a-slug", "a-better-slug"), False),
        ("a renumbering", GOOD, renumbered, True),
        ("a deleted serial handed to a new document", GOOD, revived, True),
    ]

    ok = True
    print("self-test: each known-bad input must be rejected")
    for label, dirs, text, should_fail in tree_cases:
        tmp = tempfile.mkdtemp()
        try:
            build(tmp, dirs, text)
            failed = bool(check_tree(tmp, text))
        finally:
            shutil.rmtree(tmp)
        if failed != should_fail:
            ok = False
        print(f"  {'ok ' if failed == should_fail else 'BAD'} {label}: "
              f"{'rejected' if failed else 'accepted'}")
    for label, before, after, should_fail in base_cases:
        failed = bool(check_against_base(before, after))
        if failed != should_fail:
            ok = False
        print(f"  {'ok ' if failed == should_fail else 'BAD'} {label}: "
              f"{'rejected' if failed else 'accepted'}")
    return 0 if ok else 1


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = "HEAD"
    if "--base" in argv:
        base = argv[argv.index("--base") + 1]
    with open(os.path.join(root, REGISTER), encoding="utf-8") as fh:
        text = fh.read()

    problems = check_tree(root, text)
    base_text = base_register(root, base)
    if base_text is None:
        # An unmet precondition is a failure, not a skip. A skipped comparison
        # reads exactly like a passing one, and this is the check that stops a
        # renumbering. The one exception clears itself: after the change that
        # adds the register lands, no later base lacks it.
        if register_is_new(root, base):
            print(f"{REGISTER} is added in this change, so {base} has none to hold it against")
        elif "--allow-missing-base" in argv:
            print(f"no register at {base}, and --allow-missing-base was given")
        else:
            problems.append(f"no {REGISTER} at {base}, so nothing held the register in place")
    else:
        problems += check_against_base(base_text, text)

    for line in problems:
        print(line)
    allocated, deleted = read(text)
    print(f"{len(allocated)} allocated, {len(deleted)} deleted, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main(sys.argv))
