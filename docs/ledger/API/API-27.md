---
id: API-27
title: "Coût du lot de géométries — ce qui reste après 2.0.0"
status: open
group: "Cache, fraîcheur et images — quatre briques indépendantes"
verified: 2026-11-16
---

## Reste à faire

### `API-27` Coût du lot de géométries — ce qui reste après 2.0.0

Le paramètre `simplify` et `…/elevation-profile` ont été supprimés en 2.0.0 (`API-40`).

`MAX_BULK_SLUGS = 50` est désormais le *seul* garde-fou du
lot, sur un endpoint `@PermitAll` que seule borne la limite globale par client (`SEC-28`, en nombre
de requêtes, pas en poids). Un lot réaliste de 50 parcours pèse
3,2 Mo ; les 50 plus lourds de la base pèsent 64 Mo (chiffres à remesurer : la base compte deux
fois plus de parcours depuis l'import de n-peloton). Ce cas suppose un appelant qui sait lesquels
sont les plus lourds et les nomme tous : c'est un sujet de **rate limiting**, pas de contrat. Le
levier si ça devient sensible est de descendre `MAX_BULK_SLUGS` vers ~15 (les appelants réels
plafonnent à 12, `kTripTrackStageCap`), pas de réintroduire un paramètre de finesse.
