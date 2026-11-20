---
id: OPS-65
title: "Générateur de parcours : osm-route-details 1.13, attracteurs OSM posés et non actifs"
status: open
size: "S"
kind: recette
verified: 2026-11-20
---

## Reste à faire

`OPS-65` **Générateur de parcours : osm-route-details 1.13, attracteurs OSM posés et non actifs** — passer la pile
partagée de `1.12.0` à `1.13.0` (4d du lot 4 d'`API-207`, plan §12 septies), sans changement de contrat côté Pédalons.
Les deux fichiers d'attracteurs de la France (`<ORD_GRAPH_NAME>.road.orda` et `.gravel.orda`, construits par
`ord-graph-build attractors` sur l'extrait du graphe) sont posés en 0444 à côté des vues, dont le service déduit leurs
chemins. Les attracteurs restent `off` (décision du 20 novembre 2026 : aucun réglage ne tient tous les critères) :
parcours identiques à la 1.12, aucun redépôt (`graph_id`, `params_hash` et profils inchangés). À voir :
`/v1/capabilities` rend `generator.attractors.available = true` et `enabled = false`, le service démarre sans
avertissement sur les fichiers.
