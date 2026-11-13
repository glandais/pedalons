using Toybox.Lang;
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
        [:distance, 92400.0, true, true, "km", "92,4\u00A0km"],
        [:distance, 92400.0, true, false, "km", "92.4\u00A0km"],
        [:distance, 46300.0, false, false, "mi", "28.8\u00A0mi"],
        [:distance, 46300.0, false, true, "mi", "28,8\u00A0mi"],
        [:elevation, 1240.0, true, true, "m", "1\u00A0240\u00A0m"],
        [:elevation, 1240.0, true, false, "m", "1,240\u00A0m"],
        [:elevation, 980.0, true, true, "m", "980\u00A0m"],
        [:elevation, 1240.0, false, false, "ft", "4,068\u00A0ft"],
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
