---
id: WEB-62
title: "L'outillage i18n remis en état et en CI"
status: done
group: "Outillage"
done: 2026-10-12
---

## Livré

`WEB-62` **L'outillage i18n remis en état et en CI** (2026-10-12, sans changement de contrat)
— audit du jour : `pnpm i18n:extract` retirait 248 clés de `fr/common.json` (dont ~218 encore
servies, `errors.api.*` en tête : l'extracteur ne déduit pas les clés construites d'un enum
Orval), en remplissait 51 de `___MISSING_TRANSLATION___` et réordonnait tout ; `i18n:lint` et
`i18n:status` échouaient toujours, et aucun des trois n'était en CI. Fait :
`frontend/i18next.config.ts` passe à `removeUnusedKeys: false` et ignore les tests ; les deux
catalogues sont triés une fois par i18next-cli (alphabétique, formes plurielles dans l'ordre
CLDR) et `pnpm format` (donc `./format.sh frontend`) les retrie ; le script `i18n:extract`,
redondant avec lui, est retiré. Cinq faux pluriels, qui recevaient `count` comme simple
variable et qu'`extract` aurait fait afficher `___MISSING_TRANSLATION___`, prennent un autre nom
(`length`, `total`, `registered`) — sauf `calendar.schedule.moreLabel` (« +1 autres »), devenu un
vrai pluriel. Les 36 pluriels français sans `_many` le reçoivent (texte de `_other`). Les 30 clés
mortes sont retirées (`garmin.*`, `device.*`, `nav.avatar`, `calendar.empty`…, vérifiées sans
appel littéral ni construit). La mention de fuseau ne passe plus qu'`ofCity`/`ofFrom`/`ofTo`,
que l'anglais lit aussi (`zoneCityOf` y rend le nom nu) : plus de paramètre inutilisé dans une
langue, d'où les 4 faux positifs d'`i18n:lint`. `pnpm i18n:check` (`extract --ci --dry-run`,
`lint`, `status`) tourne dans `pnpm check` et en CI (étape « Translation catalogues » de
`ci.yml`), `format:check` vérifie aussi le tri ; `catalogues.test.ts` exige toutes les formes
plurielles de chaque langue et refuse un `___MISSING_TRANSLATION___` laissé. Au passage, les sept
tests qui remplaçaient localement le mock de `ResizeObserver` de `src/test/setup.ts` (une classe
depuis `WEB-69`) ne le font plus. `frontend/CLAUDE.md` décrit les règles et ce que vérifie
chaque contrôle. `src/locales/group-by-value.js` (repérage ponctuel des traductions en double,
lancé à la main) est gardé. Tests : `catalogues.test.ts`, `TimezoneChangePreview.test.tsx`,
`npx vitest run` (412), `pnpm i18n:check`, `pnpm typecheck`, `pnpm lint`, `pnpm build`.
À ne pas défaire : **`removeUnusedKeys` reste `false`** — i18next-cli ne voit pas les clés
construites d'un enum Orval, c'est le typecheck (`WEB-73`) qui garantit qu'une clé existe ;
**`count` est réservé aux pluriels** ; une valeur qui diffère selon la langue est calculée en
un seul paramètre que toutes les langues lisent.
