---
id: OPS-65
title: "Générateur de parcours : osm-route-details 1.13, attracteurs OSM posés et non actifs"
status: done
size: "S"
done: 2026-11-20
---

## Livré

`OPS-65` **Générateur de parcours : osm-route-details 1.13, attracteurs OSM posés et non actifs** — la pile partagée est
passée de `1.12.0` à `1.13.0` le 20 novembre 2026 (4d du lot 4 d'`API-207`, plan §12 septies), sans changement de
contrat côté Pédalons. Les deux fichiers d'attracteurs de la France (`<ORD_GRAPH_NAME>.road.orda`, 9,8 Mo, et
`.gravel.orda`, 11,9 Mo) ont été construits par `ord-graph-build attractors` sur l'extrait du graphe. Ils sont posés en
0444 à côté des vues, dont le service déduit leurs chemins ; le graphe et la vue route du serveur ont été vérifiés
identiques à ceux de la construction. Constaté après le déploiement : le service démarre sans avertissement
(« generator attractors loaded », `enabled: false`), `/v1/capabilities` rend
`generator.attractors = {available: true, enabled: false}`, et aucune surcouche n'est passée `stale`. Les
attracteurs restent `off` par décision du 20 novembre 2026, car aucun réglage ne tient tous les critères : les parcours
sont ceux de la 1.12 et aucun redépôt n'est nécessaire. Un fichier `.orda` absent rend seulement les attracteurs
indisponibles. Un nouveau graphe demande ses deux fichiers sous son nouveau nom.
