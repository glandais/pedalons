---
id: API-83
title: "Miniatures des lignes de voyage hors `ThumbnailLookup`"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-83` **Miniatures des lignes de voyage hors `ThumbnailLookup`** (2026-10-06, pas de
changement de contrat) — reste de `API-80` : `TripDto.build` parcourait `trip.getAssets()`, puis
`trip.getRoute().getAssets()` en repli, pour chaque ligne de liste. `PublicationService.list`
résout maintenant les miniatures de tous les voyages de la page en une requête,
`ThumbnailLookup.forTrips` (filtrée par domaine ; le voyage d'abord, son parcours en repli — la
règle d'avant), que `TripDto.fromListItem` lit comme les autres lookups de page. `forRides` et
`forTrips` partagent la même méthode (`ownElseRoute`, le `route` de la publication étant un
to-one eager déjà chargé). Le détail d'un voyage garde le parcours des assets
(`TripDto.ownOrRouteThumbnail`). Couvert par
`PublicationQueryCountTest.listTeamTrips_routeThumbnails_costAPageNotARow` (30 voyages sur 30
parcours à miniatures, un sur trois avec la sienne : chaque ligne porte la bonne image, et le
nombre de requêtes ne croît pas avec la page). Même réserve que pour les sorties : le test ne
budgète que les requêtes, `MediaDto` lit toujours l'inventaire d'assets de chaque ligne, et le
rôle de collection `TeamEntity.assets`, partagé par sorties, voyages et parcours, laisse le batch
fetch hydrater les assets des parcours au passage. **À ne pas défaire** : une ligne de liste ne
lit pas `getAssets()` pour sa miniature, et la miniature propre du voyage passe avant celle de son
parcours, variantes claire et sombre comprises.
