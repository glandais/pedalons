---
id: API-3
title: "Vignette du parcours du groupe"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-3` | **Vignette du parcours du groupe** (2026-09-30) — **API 5.10.0** : `RideGroupDto.thumbnailLightUrl`, `thumbnailDarkUrl` et `thumbnailUrl` (la claire d'abord, sinon la sombre — la règle de `RideDto`), tous nullables, les vignettes du parcours du groupe. Les deux variantes thémées sont là en plus du champ réduit parce que le mobile rend la sombre en thème sombre. Nuls pour un groupe sans parcours : **jamais la vignette de la sortie en repli côté serveur**, le client l'a déjà. Résolues pour tous les groupes de la sortie par **une** requête `ThumbnailLookup.forTeamEntities` (`RideService.toDto`) ; ne pas remplacer par une marche sur `route.getAssets()` par groupe. Les groupes n'étant rendus que sur le détail, la liste n'est pas touchée. Le mobile (`next_ride_card.dart`, « Ma prochaine sortie ») rend la vignette du groupe, celle de la sortie en repli (`nextRideThumbnailUrl`). Le web ne rendait pas de vignette par groupe : rien à changer. Couvert par `RideResourceTest.getRide_groupsCarryTheirOwnRouteThumbnail` (deux variantes, sombre seule, groupe sans parcours), `PublicationQueryCountTest.rideDetail_groupRouteThumbnails_costDoesNotScaleWithGroupCount` (1 puis 6 groupes sur 6 parcours) et `next_ride_thumbnail_test.dart` | 11 |
