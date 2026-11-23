---
id: OPS-68
title: "Mettre en service osm-route-details 1.16.0 (itinéraire de A à B, api 1.15)"
status: open
size: "S"
kind: externe
verified: 2026-11-23
---

## Reste à faire

`OPS-68` **Mettre en service osm-route-details 1.16.0 (itinéraire de A à B, api 1.15)** —
le calcul d'itinéraire du planificateur (`API-217`) a besoin du moteur `1.16.0` : `POST /v1/router/route` et
le bloc `router` de `/v1/capabilities` (api 1.15). Tant que le service en production est en `1.15.x`,
`GET /api/router/engines` n'offre que Stadia et l'option n'apparaît pas : rien ne casse, rien n'est
livré non plus. À faire dans osm-route-details : relire et commiter les lots 1 et 2 (non commités au
23 novembre 2026), publier l'image `1.16.0`, la déployer dans la pile partagée (aucun fichier de graphe
à reconstruire, les générations sont inchangées au bit près), puis vérifier `capabilities.router.enabled`
et les métriques `ord_router_*`. Réglages nouveaux, défauts à mesurer en charge :
`generator.router_max_concurrent` (2), `router_max_queued` (6), `router_budget_ms` (5 000).
