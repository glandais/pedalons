---
id: API-81
title: "Vitesse facultative par étape de voyage"
status: done
group: "Petites évolutions d'API"
done: 2026-10-06
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-81` | **Vitesse facultative par étape de voyage** (2026-10-06) — **API 10.10.0** : `StageRequest.averageSpeed` et `TripStageDto.averageSpeed`, nullables, en km/h, `@Positive` — la forme et l'unité de `RideGroupDto.averageSpeed`. Colonne `team_entities.average_speed` (V62, `float4` nullable : la version précédente insère sans la connaître pendant un déploiement progressif). Comme tout champ d'étape, un PUT l'applique tel quel : nul l'efface. Exportée avec l'étape (`content/trip-stages.json`). Web : champ « Vitesse moyenne » dans l'onglet de chaque étape de `TripEditor` (unités de l'utilisateur, `useUnits`), rendue à côté de la date sur `StageDetailPage` ; `tripToRequest` la reporte — **à ne pas retirer**, le menu publier/dépublier/annuler de la fiche l'effacerait. Mobile : statistique de `StageCard` et ligne de départ de l'écran 25 ; le mobile n'édite pas les voyages. C'est la vitesse que la météo des voyages (`API-76`) prendra pour une étape, 25 km/h à défaut. Test : `TripServiceTest.shouldCreateWithStages` (vitesse posée sur une étape, nulle sur l'autre) | 25 |
