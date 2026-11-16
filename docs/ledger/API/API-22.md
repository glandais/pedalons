---
id: API-22
title: "`ETag` / `If-None-Match`"
status: open
size: "M"
group: "Cache, fraîcheur et images — quatre briques indépendantes"
verified: 2026-11-16
---

## Reste à faire

`API-22` **`ETag` / `If-None-Match` (M)** — le verrou est que les champs « moi »
(`registered`, `registeredGroupId`, `full`, `commentCount`) rendent les réponses dépendantes
de l'appelant. Un `ETag` calculé sur le contenu métier seul serait faux et un cache partagé
servirait à Alice la réponse de Bob. Recommandation actée : intégrer `userId` au calcul et
servir `Cache-Control: private` — le gain visé est le cache **du client**, pas d'un CDN.
La mécanique existe déjà pour la météo (`API-74`) : `ETag` faible, `If-None-Match` → 304 et
`Cache-Control: private, no-cache` (`RideResource`, `TripResource`, `RideWeatherAnswer`), à
prendre pour modèle. Reste à l'étendre aux détails sortie, parcours et voyage, puis aux
listes, avec `userId` dans le calcul.
