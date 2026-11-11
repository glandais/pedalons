# `format-cases.json` — the formats both clients must agree on

One list of cases, read by the tests of the app **and** of the site: a value, a language and a unit system, and the
exact text both formatters must return. It is what keeps a « 92.4 km » from coming back on one side only (ledgers
`MOB-139`, `WEB-167`; rules in `docs/BRANDING.md` §8.3 and the cards' `KIT.md` §8–9).

Each case is `{ "kind", "input", "locale": "fr" | "en", "units": "metric" | "imperial", "now"?, "expected", "note"? }`.
`kind` is one of `distance` (metres), `elevation` (metres), `speed` (km/h), `percent`, `grade`, `price`
(`{ price, rentalPeriod? }`, `price: null` for « à négocier »), `shortDateTime` (`{ date, zone }`: a publication's or
an ad's date), `tripSpan` (`{ start, end, zone }`), `relative` (`{ date, zone }`, the reader's zone) and `memberSince`
(`{ date, zone }`). `now` (UTC) pins « today » and « this year ». Dates are UTC instants, zones IANA names.

**Spaces are written escaped**: ` ` (no-break, between a value and its unit) and ` ` (narrow no-break, the
French thousands separator and the English space before AM/PM). Never paste them raw: an editor shows them as spaces.

**Adding a case**: append it, then run both tests. If the app and the site disagree, fix the formatter that breaks the
written rule (BRANDING §8.3, KIT §8–9); where no rule decides, the app's rendering wins and the case says so in `note`.
A new `kind` needs a branch in both tests.

**Read by** `mobile/test/core/utils/format_cases_test.dart` (`flutter test`) and
`frontend/src/utils/formatCases.test.ts` (`pnpm test`).
