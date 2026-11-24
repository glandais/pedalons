---
id: OPS-69
title: "Mettre en service osm-route-details 1.18.0 (retouche, api 1.17)"
status: open
size: "S"
kind: externe
verified: 2026-11-24
---

## Reste à faire

`OPS-69` **Mettre en service osm-route-details 1.18.0 (retouche, api 1.17)** — le moteur gagne
`POST /v1/generator/routes/edit` (`capabilities.generator.edit`) ; tant qu'il n'est pas déployé, la production
reste en 1.17.1 et l'action « Retoucher » (`API-212`, `WEB-201`) n'apparaît pas, rien ne casse. À faire par le
propriétaire :

- déployer la pile partagée (`scripts/deploy.sh --shared`) : l'image `1.18.0` est publiée et épinglée dans
  `docker-compose.shared.yml` depuis le 24 novembre 2026 ;
- à la recette, lire `ord_generator_edit_requests_total` (part de `order_anomaly` et `route_mismatch` : au-delà
  de 10 %, la piste du §15.3 de la note du moteur), `ord_generator_edit_stage_seconds{stage="match"}` (cache des
  poses au-delà de 200 ms au P90) et la mémoire de l'index (`ORD_GENERATOR__EDIT_INDEX_CACHE_MB`, 64) ;
- vérifier que la page d'un parcours prêt offre l'action dans l'heure (cache des capacités) ;
- compléter la section « The route generator » de `docs/OPERATIONS.md` (capacité `edit`, métriques).

Plan [`2026-11-24-retouche-parcours-lot7c.md`](../../plans/2026-11-24-retouche-parcours-lot7c.md) §11.
