"""Writes source/FormatCasesTest.mc from contracts/format-cases.json: the `distance` and
`elevation` cases the app, the site and the Karoo extension already agree on, checked here
against Fmt (FormatUtils.mc). The dates are not covered: their weekday and month come from the
Edge's firmware, in its language.

    python3 scripts/format-vectors.py    # then `make test`
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CASES = json.loads((ROOT.parent / "contracts" / "format-cases.json").read_text(encoding="utf-8"))
UNITS = {("distance", "metric"): "km", ("distance", "imperial"): "mi",
         ("elevation", "metric"): "m", ("elevation", "imperial"): "ft"}


def literal(text):
    return '"' + "".join(c if ord(c) < 128 else "\\u%04X" % ord(c) for c in text) + '"'


rows = []
for case in CASES:
    kind = case["kind"]
    if kind not in ("distance", "elevation"):
        continue
    rows.append(
        "        [:%s, %s, %s, %s, %s, %s],"
        % (kind, repr(float(case["input"])), str(case["units"] == "metric").lower(),
           str(case["locale"] == "fr").lower(), literal(UNITS[kind, case["units"]]),
           literal(case["expected"]))
    )

(ROOT / "source" / "FormatCasesTest.mc").write_text(
    """using Toybox.Lang;
using Toybox.Test;

/**
 * Fmt against contracts/format-cases.json, the formats the app, the site and the Karoo
 * extension agree on. Generated: `python3 scripts/format-vectors.py`, never edited by hand.
 * Run with `make test` (simulator started).
 */
(:test)
module FormatCasesTest {
    // [kind, metres, metric, french, unit, expected]
    const CASES = [
%s
    ];

    (:test)
    function matchesTheSharedCases(logger as Test.Logger) as Lang.Boolean {
        var ok = true;
        for (var i = 0; i < CASES.size(); i++) {
            var c = CASES[i];
            var got =
                c[0] == :distance
                    ? Fmt.distance(c[1], c[2], c[3], c[4])
                    : Fmt.elevation(c[1], c[2], c[3], c[4]);
            if (!got.equals(c[5])) {
                logger.error("case " + i + ": expected " + c[5] + ", got " + got);
                ok = false;
            }
        }
        return ok;
    }
}
"""
    % "\n".join(rows),
    encoding="utf-8",
)
print(len(rows), "cases")
