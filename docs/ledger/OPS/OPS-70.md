---
id: OPS-70
title: "Accélérer le match d'une retouche dans osm-route-details (P90 ≈ 2,1 s pour 200 ms visés)"
status: open
size: "M"
verified: 2026-11-25
---

## Reste à faire

`OPS-70` **Accélérer le match d'une retouche dans osm-route-details (P90 ≈ 2,1 s pour 200 ms visés)** —
en production (moteur `1.18.0`, relevé du 2026-11-25 sur 28 retouches), l'étape `match` de
`POST /v1/generator/routes/edit` (`ord_generator_edit_stage_seconds{stage="match"}`, champ `match_ms` des
journaux `route edit`) prend de 1,5 à 2,1 s, une seule fois 0,4 s ; `engine`, `pose` et `check` restent
sous 0,3 s. Une retouche attend donc environ 2 s de plus que nécessaire, à chaque « Proposer » (`WEB-201`).
Le plan fixait le seuil à 200 ms au P90, au-delà duquel le cache des poses devient nécessaire :

- côté moteur (dépôt osm-route-details) : mettre en cache les poses d'un parcours (clé : sa géométrie et
  l'id du graphe), mesurer à nouveau `match_ms`, publier une version et l'épingler dans
  `docker-compose.shared.yml` ;
- vérifier que la mémoire tient (conteneur à 1,18 Gio sur 3 Gio le 2026-11-25, index borné par
  `ORD_GENERATOR__EDIT_INDEX_CACHE_MB`, 64) ;
- garder un œil sur les `checker_rejected` de `resize` (5 sur 28, dont 3 tracés écartés pour
  `DISTANCE_OUT_OF_TOLERANCE`) : sans objet pour le seuil de 10 % (`order_anomaly` et `route_mismatch` à 0),
  mais une part qui ne baisse pas mérite un regard ;
- compléter la section « The route generator » de `docs/OPERATIONS.md` : capacité `edit`, métriques
  `ord_generator_edit_*`, seuils ci-dessus (laissé ouvert par `OPS-69`).

Plan [`2026-11-24-retouche-parcours-lot7c.md`](../../plans/2026-11-24-retouche-parcours-lot7c.md) §11 ;
note du moteur `docs/design/technique/ord-retouche-lot1.md` §15 (dépôt osm-route-details).
