---
id: API-9
title: "Plage de dates d'un voyage dans « Utilisée dans »"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-9` | **Plage de dates d'un voyage dans « Utilisée dans »** (2026-09-30) — **API 5.9.0** : `RouteUsageDto.endDate`, nullable, la date de la dernière étape non supprimée — la règle de `TripDto.endDate` (le maximum des dates, pas la dernière par rang). Nul pour une sortie et pour un voyage sans étape, qui dure un jour. Aucune requête de plus : `fromTrip` parcourait déjà les étapes pour `viaChildNames`. Le mobile (`route_usages_section.dart`) rend « 1 août → 4 août » comme la carte de voyage, le web (`RouteUsages.tsx`) les deux dates au lieu de la date et l'heure de début ; une sortie garde sa date et son heure. Couvert par `RouteResourceTest.getRouteUsages_trip_carriesItsEndDate_rideDoesNot` (une étape supprimée plus tardive ignorée, voyage sans étape et sortie à nul) et `route_usages_section_test.dart` | 13 |
