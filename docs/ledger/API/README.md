# API — Contrat d'API et backend

Contexte des entrées `API-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte


### Extension Karoo : ce que le découpage de novembre 2026 a figé sans le corriger

Le découpage de `MainActivity.kt` (`AUD-22`) a conservé le comportement tel quel, défauts compris :
chacun est tenu par un test marqué `CHARACTERIZATION:` dans `karoo/app/src/test/`. En corriger un,
c'est changer ce test exprès, dans le même commit.

### Météo : ce qui suit `API-74`

La météo des **sorties** est livrée (`API-74`, `WEB-60`, `MOB-51`, contrat `10.9.0`), celle des
**étapes de voyage** aussi (`API-76`, `WEB-67`, `MOB-57`, contrat `10.11.0`), et la ligne des
cartes de voyage (`API-82`, contrat `10.13.0`). Le plan
[`2026-10-05-weather.md`](../../plans/archive/2026-10-05-weather.md) est archivé : il garde les
arbitrages, ce qui suit est ici (et les recettes des sorties, `WEB-61`, `MOB-52`, `OPS-29`).

### Les chantiers d'infrastructure d'API

Quatre chantiers ont été chiffrés au §4 du
[document d'API archivé](../../plans/archive/2026-07-26-api-v2-livraison-et-suites.md) (contrat, modèle,
déclenchement, risques). Seul le push a été livré depuis (`NOTIF-9`) ; les trois autres n'ont pas été
commencés, si ce n'est l'`ETag` privé de la météo, qui sert de modèle à `API-22`. Résumé et ordre
recommandé :

#### Cache, fraîcheur et images — quatre briques indépendantes

Ensemble, elles débloquent le chargement progressif du parcours, de vrais placeholders colorés à la
place des squelettes, et le **hors-ligne — qui n'est dans aucune maquette et devrait l'être avant
d'être promis**.

### Petites évolutions d'API qui suppriment chacune une dégradation nommée

Extrait du §5.2 du plan mobile. Aucune ne bloque un écran ; chacune retire un repli visible.
Beaucoup sont des ajouts d'un champ — le rapport valeur/effort y est bon. Les numéros reprennent
ceux du plan (`API-1`, l'URL de tuile authentifiable, est livré).


Le meneur de groupe (`API-41`, livré en 1.5.0), l'URL de tuile (`API-1`) et la pagination du
calendrier (`API-20`) sont dans
[`LEDGER_DONE.md`](../../LEDGER_DONE.md). Les **gabarits de sortie n'ont volontairement pas de meneur** —
décision produit : `RideTemplateGroupRequest` reste sans champ.

### Envoi automatique des parcours vers les services GPS : ce qui reste après `API-120`

Le cœur d'`API-120` (contrat `11.5.0`, migration `V71`, planificateur et worker, envois manuels
suivis dans `gps_route_syncs`) est livré et tourne en prod depuis le 16 octobre 2026 : 3 connexions
en envoi automatique (Hammerhead, Wahoo, Garmin OAuth 1.0a), 5 parcours envoyés sans erreur.
`GPS_SYNC_ENABLED` vaut `true` en prod et en staging ; la politique le décrit depuis le
16 octobre 2026 (`LEGAL-21`), et `docs/OPERATIONS.md` le documente ; reste la recette sur
appareil (`OPS-42`, étape 7 du plan
[`2026-10-16-gps-route-autosync.md`](../../plans/2026-10-16-gps-route-autosync.md)).



## Livré : contexte








### Concurrence : constats de la modélisation formelle du 11 octobre 2026

Une modélisation TLA+/TLC et Lean 4 du backend ([`formal/`](../../formal/) ; deux instances pendant un
déploiement start-first, READ COMMITTED) a mis au jour dix-sept défauts ; chacun a été reproduit par un test qui échouait
avant le correctif. Les constats de sécurité sont sous `SEC-34` à `SEC-38`, les autres sous `NOTIF-10`,
`ISSUE-8`, `ISSUE-9`, `MIG-15`.

### Reprises immédiates

Le détail de chacune est dans l'historique git de ce fichier et de `LEDGER_NEXT.md` (ex-`NEXT.md`).




