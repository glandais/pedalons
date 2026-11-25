---
id: OPS-69
title: "Mettre en service osm-route-details 1.18.0 (retouche, api 1.17)"
status: done
size: "S"
done: 2026-11-25
---

## Livré

`OPS-69` **Mettre en service osm-route-details 1.18.0 (retouche, api 1.17)** — le moteur a été déployé
dans la pile partagée par le propriétaire le 24 novembre 2026 (image
`ghcr.io/glandais/osm-route-details:1.18.0`, épinglée dans `docker-compose.shared.yml`) :
`POST /v1/generator/routes/edit` et `capabilities.generator.edit` (`resize`, `move_end`). L'action
« Retoucher » (`API-212`, `WEB-201`) sert en production : relevé du 2026-11-25, 28 retouches (22 `resize`,
6 `move_end`), `order_anomaly` et `route_mismatch` à 0, 5 `checker_rejected` sur `resize`, conteneur à
1,18 Gio sur 3 Gio.

La recette a montré l'étape `match` à environ 2,1 s au P90, dix fois le seuil de 200 ms : le cache des poses
et la section « The route generator » de `docs/OPERATIONS.md` passent à `OPS-70`.

À ne pas défaire : l'offre de la retouche dépend de `capabilities.generator.edit` (cache des capacités d'une
heure), si bien qu'un retour à `1.17.1` masque l'action sans rien casser.
