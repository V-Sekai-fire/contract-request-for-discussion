# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Check `pen-66606.usda`, the composed view of every serial the PEN has issued.

WHY THIS EXISTS. A serial is the last arc of an OID under PEN 66606, so it names one
document for as long as the arc exists. Each manual site keeps its own register and
authors only its own serials. This layer sublayers those registers into one stage. It
stores no serial itself, because a register duplicated across sites is not a record: the
first copy edited would win by accident and nothing would report the other.

The composition is what makes that arrangement safe and also what makes it silent when it
breaks. USD composes a sublayer that resolves and says nothing about one that does not,
the same way it says nothing about a relationship whose target is missing. Two sites
authoring the same serial compose into one prim with one value, which reads exactly like
agreement. Neither `usdchecker` nor `check_usd_valid.py` has an opinion about either.

WHAT IT CHECKS.
1. Every sublayer resolves.
2. A site authors only its own serials.
3. No two sites author the same serial.
4. Every declared site contributes a register or is excused in `sitesWithoutRegister`.
5. Column arrays declared by a relation are parallel.
6. A site marked `decommissioned` in `sites` has a row in `sitesDecommissioned`.

Run --self-test for the controls, one per known-bad input.
"""
import pathlib
import re
import sys

from pxr import Sdf, Usd

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_LAYER = HERE.parent / "pen-66606.usda"
SITE_RE = re.compile(r"^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(decommissioned))?$")
WITHOUT_RE = re.compile(r"^(\d+)\s+(.+)$")
DECOMMISSIONED_RE = re.compile(r"^(\d+)\s")


def open_layer(path):
    stage = Usd.Stage.Open(str(path))
    if stage is None:
        raise SystemExit(f"{path} does not open")
    return stage


def declared_sites(layer):
    """site digit -> (owner, repository, arc, decommissioned)."""
    out = {}
    for row in layer.customLayerData.get("sites", []):
        m = SITE_RE.match(str(row).strip())
        if m:
            out[m.group(1)] = (m.group(2), m.group(3), m.group(4), m.group(5) == "decommissioned")
    return out


def decommissioned_rows(layer):
    """site digit -> its row in `sitesDecommissioned`."""
    out = {}
    for row in layer.customLayerData.get("sitesDecommissioned", []):
        m = DECOMMISSIONED_RE.match(str(row).strip())
        if m:
            out.setdefault(m.group(1), str(row))
    return out


def excused_sites(layer):
    """site digit -> the reason it contributes no register."""
    out = {}
    for row in layer.customLayerData.get("sitesWithoutRegister", []):
        m = WITHOUT_RE.match(str(row).strip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


def sublayer_paths(layer):
    return [str(p) for p in layer.subLayerPaths]


ROW_RE = re.compile(r"^S(\d+)$")


def relations(layer):
    """(prim spec path, {column: [values]}) for every relation a layer authors itself.

    Read off the Sdf layer rather than a composed stage, because the question here is
    which site authored a serial, and composition is what erases that.

    TWO SHAPES, AND BOTH ARE READ. A relation is either one prim per tuple with the
    primary key in the prim name, or parallel arrays under the relation prim. This
    site moved to the first because parallel arrays can fall out of step; other sites
    still author the second, and a reader that understood only one shape would compose
    their registers to nothing, which reads exactly like a site with no serials.
    Whichever shape a layer uses, the columns come back as parallel lists here.
    """
    found = []

    def walk(spec):
        cols = spec.attributes.get("columns")
        if cols is not None and cols.default is not None:
            names = [str(c).split()[0] for c in cols.default if str(c).strip()]
            rows = [(m.group(1), c) for c in spec.nameChildren
                    if (m := ROW_RE.match(c.name))]
            if rows:
                arrays = {n: [] for n in names}
                for key, child in rows:
                    arrays["serial"].append(int(key))
                    for name in names:
                        if name == "serial":
                            continue
                        a = child.attributes.get(name)
                        arrays[name].append(a.default if a is not None else None)
            else:
                arrays = {}
                for name in names:
                    a = spec.attributes.get(name)
                    arrays[name] = list(a.default) if a is not None and a.default is not None else None
            found.append((str(spec.path), arrays))
        for child in spec.nameChildren:
            walk(child)

    for prim in layer.rootPrims:
        walk(prim)
    return found


def site_of(spec_path, layer):
    """The site digit a relation belongs to, from the site scope in its path."""
    names = str(spec_path).strip("/").split("/")
    sites = declared_sites(layer)
    for digit, (owner, _repo, _arc, _dec) in sites.items():
        wanted = owner.replace("-", "").lower()
        for name in names:
            if name.lower() == wanted:
                return digit
    return None


def check_sublayers(root_layer, problems):
    for path in sublayer_paths(root_layer):
        resolved = Sdf.Layer.FindOrOpenRelativeToLayer(root_layer, path)
        if resolved is None:
            problems.append(f"sublayer {path} does not resolve, so its serials compose to nothing")
    return problems


def check_accounted(root_layer, problems):
    """Every declared site contributes a register or says why it does not."""
    sites = declared_sites(root_layer)
    excused = excused_sites(root_layer)
    if not sites:
        # An empty site list would make every check below vacuous, which reads exactly
        # like a pass.
        problems.append("the layer declares no site, which is never correct here")
        return problems
    contributing = set()
    for path in sublayer_paths(root_layer):
        resolved = Sdf.Layer.FindOrOpenRelativeToLayer(root_layer, path)
        if resolved is None:
            continue
        for spec_path, _arrays in relations(resolved):
            digit = site_of(spec_path, root_layer)
            if digit:
                contributing.add(digit)
    for digit in sorted(sites):
        if digit not in contributing and digit not in excused:
            owner = sites[digit][0]
            problems.append(
                f"site {digit} ({owner}) contributes no register and gives no reason"
            )
    for digit in sorted(excused):
        if digit in contributing:
            problems.append(
                f"site {digit} contributes a register and is also listed as having none"
            )
    return problems


def check_ownership_and_overlap(root_layer, problems):
    """A site authors only its own serials, and no two sites author the same one."""
    seen = {}
    for path in sublayer_paths(root_layer):
        resolved = Sdf.Layer.FindOrOpenRelativeToLayer(root_layer, path)
        if resolved is None:
            continue
        for spec_path, arrays in relations(resolved):
            digit = site_of(spec_path, root_layer)
            serials = arrays.get("serial")
            if serials is None:
                continue
            for serial in serials:
                text = str(serial)
                if digit and not text.startswith(digit):
                    problems.append(
                        f"{spec_path} is site {digit} and authors serial {text}, "
                        f"which is not its own"
                    )
                if text in seen and seen[text] != spec_path:
                    problems.append(
                        f"serial {text} is authored by {seen[text]} and by {spec_path}"
                    )
                seen[text] = spec_path
    if not seen:
        problems.append("no sublayer authors a serial, so nothing was composed")
    return problems


def check_columns_parallel(root_layer, problems):
    for path in sublayer_paths(root_layer):
        resolved = Sdf.Layer.FindOrOpenRelativeToLayer(root_layer, path)
        if resolved is None:
            continue
        for spec_path, arrays in relations(resolved):
            lengths = {}
            for name, values in arrays.items():
                if values is None:
                    problems.append(f"{spec_path} declares column {name} and authors no array")
                else:
                    lengths[name] = len(values)
            if len(set(lengths.values())) > 1:
                shown = ", ".join(f"{n} {c}" for n, c in sorted(lengths.items()))
                problems.append(f"{spec_path} column arrays are not parallel: {shown}")
    return problems


def check_decommission_declared(root_layer, problems):
    """A site marked `decommissioned` in `sites` has a row in `sitesDecommissioned`."""
    sites = declared_sites(root_layer)
    rows = decommissioned_rows(root_layer)
    for digit in sorted(sites):
        _owner, _repo, _arc, decommissioned = sites[digit]
        if decommissioned and digit not in rows:
            problems.append(
                f"site {digit} is marked decommissioned in `sites` and carries no "
                f"row in `sitesDecommissioned`"
            )
    return problems


def check(layer_path=DEFAULT_LAYER):
    problems = []
    stage = open_layer(layer_path)
    root_layer = stage.GetRootLayer()
    check_sublayers(root_layer, problems)
    check_accounted(root_layer, problems)
    check_ownership_and_overlap(root_layer, problems)
    check_columns_parallel(root_layer, problems)
    check_decommission_declared(root_layer, problems)
    return problems


GOOD_SITE = """#usda 1.0
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
    }
}
"""

SECOND_SITE = """#usda 1.0
(
    defaultPrim = "Serials"
)

def Scope "Serials"
{
    def Scope "VSekaiFabric"
    {
        def Scope "Allocated"
        {
            def "Rfd"
            {
                custom string[] columns = ["serial int16 PK", "slug string"]
                custom int[] serial = [2000]
                custom string[] slug = ["conventions"]
            }
        }
    }
}
"""

GOOD_ROOT = """#usda 1.0
(
    defaultPrim = "Serials"
    subLayers = [
        @./site1.usda@,
        @./site2.usda@
    ]
    customLayerData = {{
        string pen = "1.3.6.1.4.1.66606"
        string[] sites = [
            "1 weftspun request-for-discussion 1.3.6.1.4.1.66606.1.1",
            "2 vsekaifabric multiplayer-fabric-manuals 1.3.6.1.4.1.66606.1.2",
            "3 fire manuals 1.3.6.1.4.1.66606.1.3",
        ]
        string[] sitesWithoutRegister = [
            "3 names a decision by its date and allocates no serial",
        ]
    }}
)

over "Serials"
{{
    custom string thesis = "stores nothing"
}}
"""


def self_test():
    import shutil
    import tempfile

    def build(tmp, root=GOOD_ROOT, site1=GOOD_SITE, site2=SECOND_SITE):
        (tmp / "site1.usda").write_text(site1, encoding="utf-8")
        (tmp / "site2.usda").write_text(site2, encoding="utf-8")
        path = tmp / "pen.usda"
        path.write_text(root.format(), encoding="utf-8")
        return path

    cases = [
        ("a composed view that agrees with its sites", {}, False),
        ("a sublayer that does not resolve",
         {"root": GOOD_ROOT.replace("@./site2.usda@", "@./missing.usda@")}, True),
        ("a site authoring another site's serial",
         {"site2": SECOND_SITE.replace("custom int[] serial = [2000]",
                                       "custom int[] serial = [1500]")}, True),
        ("two sites authoring one serial",
         {"site2": SECOND_SITE.replace("custom int[] serial = [2000]",
                                       "custom int[] serial = [1001]")
          .replace('def Scope "VSekaiFabric"', 'def Scope "VSekaiFabric"')}, True),
        ("a declared site that is neither composed nor excused",
         {"root": GOOD_ROOT.replace(
             '        string[] sitesWithoutRegister = [\n'
             '            "3 names a decision by its date and allocates no serial",\n'
             '        ]\n', '        string[] sitesWithoutRegister = []\n')}, True),
        ("a site both composed and listed as having none",
         {"root": GOOD_ROOT.replace(
             '"3 names a decision by its date and allocates no serial",',
             '"1 names a decision by its date and allocates no serial",')}, True),
        ("column arrays that are not parallel",
         {"site1": GOOD_SITE.replace('custom string[] slug = ["conventions", "a-slug"]',
                                     'custom string[] slug = ["conventions"]')}, True),
        ("a declared column with no array",
         {"site1": GOOD_SITE.replace('custom string[] slug = ["conventions", "a-slug"]', "")}, True),
        ("no site authoring anything",
         {"site1": GOOD_SITE.replace("custom int[] serial = [1000, 1001]",
                                     "custom int[] serial = []")
          .replace('custom string[] slug = ["conventions", "a-slug"]',
                   "custom string[] slug = []"),
          "site2": SECOND_SITE.replace("custom int[] serial = [2000]",
                                       "custom int[] serial = []")
          .replace('custom string[] slug = ["conventions"]', "custom string[] slug = []")}, True),
        ("a decommissioned site with no row in sitesDecommissioned",
         {"root": GOOD_ROOT.replace(
             '"1 weftspun request-for-discussion 1.3.6.1.4.1.66606.1.1",',
             '"1 weftspun request-for-discussion 1.3.6.1.4.1.66606.1.1 decommissioned",')}, True),
        ("a decommissioned site with a matching row in sitesDecommissioned",
         {"root": GOOD_ROOT.replace(
             '"1 weftspun request-for-discussion 1.3.6.1.4.1.66606.1.1",',
             '"1 weftspun request-for-discussion 1.3.6.1.4.1.66606.1.1 decommissioned",')
          .replace(
             '        string[] sitesWithoutRegister = [\n',
             '        string[] sitesDecommissioned = [\n'
             '            "1 decommissioned 2026-08-31. Test row.",\n'
             '        ]\n'
             '        string[] sitesWithoutRegister = [\n')}, False),
    ]

    ok = True
    print("self-test: each known-bad input must be rejected")
    for label, kw, should_fail in cases:
        tmp = pathlib.Path(tempfile.mkdtemp())
        try:
            path = build(tmp, **kw)
            failed = bool(check(path))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        if failed != should_fail:
            ok = False
        print(f"  {'ok ' if failed == should_fail else 'BAD'} {label}: "
              f"{'rejected' if failed else 'accepted'}")
    return 0 if ok else 1


def main(argv):
    path = pathlib.Path(argv[1]) if len(argv) > 1 else DEFAULT_LAYER
    problems = check(path)
    for line in problems:
        print(line)
    print(f"{len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main(sys.argv))
