---
id: OPS-68
title: "Mettre en service osm-route-details 1.16.0 (itinéraire de A à B, api 1.15)"
status: done
size: "S"
done: 2026-11-24
---

## Livré

`OPS-68` **Mettre en service osm-route-details 1.16.0 (itinéraire de A à B, api 1.15)** —
le moteur a été déployé dans la pile partagée par le propriétaire le 24 novembre 2026, en `1.17.1`
(image `ghcr.io/glandais/osm-route-details:1.17.1`, épinglée dans `docker-compose.shared.yml`) :
`POST /v1/router/route` et le bloc `router` de `/v1/capabilities` (api 1.16, avec `use_roads` et
`avoid_main_roads` depuis `1.17.0`), plus le correctif du virage serré, qui coûte 200 à 250 m au lieu
d'être refusé (avant, un itinéraire pouvait faire plusieurs fois la distance pour en éviter un). Aucun
fichier de graphe n'a été reconstruit, les générations sont inchangées. `GET /api/router/engines`
offre depuis le moteur Pédalons à côté de Stadia (`API-217`).

À ne pas défaire : le backend n'envoie `use_roads` et `avoid_main_roads` que si le moteur les annonce
dans ses capacités, si bien qu'un retour à `1.16.0` reste sans casse. Les réglages
`generator.router_max_concurrent` (2), `router_max_queued` (6) et `router_budget_ms` (5 000) sont
restés à leurs défauts, non mesurés en charge.
