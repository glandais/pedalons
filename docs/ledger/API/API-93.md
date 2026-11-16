---
id: API-93
title: "Statistiques de voyage stockées en base"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-93` | **Statistiques de voyage stockées en base** (BACKLOG « Trip stats (save in DB) ») | Non (décidé le 9 octobre 2026 avec le propriétaire) | `TripDto.totalDistance` et `totalElevationGain` (contrat `1.3.0`) sont calculés à la lecture, une requête par page (`TripSummaryRepository.loadStageAggregates`), et suffisent aux écrans web et mobile. Une colonne dénormalisée devrait suivre chaque modification d'étape ou de parcours, comme la fin stockée (`API-85`, `API-87`). À rouvrir sur une mesure réelle de coût |
