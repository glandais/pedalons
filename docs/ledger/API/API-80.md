---
id: API-80
title: "Miniatures des lignes de sortie hors `ThumbnailLookup`"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-80` **Miniatures des lignes de sortie hors `ThumbnailLookup`** (2026-10-06, pas de
changement de contrat) — relevé pendant `API-79` : `RideDto` construisait chaque ligne de liste
en parcourant `ride.getAssets()`, puis `ride.getRoute().getAssets()` en repli, une collection
chargée par ligne que seul `fetch.batch-size=32` regroupait. `PublicationService.list` résout
maintenant les miniatures de toutes les sorties de la page en une requête,
`ThumbnailLookup.forRides` (ids des sorties et de leurs parcours, la sortie d'abord, son parcours
en repli — la règle d'avant, celle du calendrier) ; `RideDto.fromListItem` lit cette carte, comme
les autres lookups de page. Le détail d'une sortie garde le parcours des assets
(`ownOrRouteThumbnail`, une seule sortie, inventaire déjà lu par `MediaDto`). Couvert par
`PublicationQueryCountTest.listTeamRides_routeThumbnails_costAPageNotARow` (30 sorties sur 30
parcours à miniatures, une sur trois avec la sienne : chaque ligne porte la bonne image, et le
nombre de requêtes ne croît pas avec la page). Le test ne budgète que les requêtes, pas les
entités : `MediaDto` lit toujours l'inventaire de chaque sortie, et le rôle de collection
`TeamEntity.assets` étant partagé avec les parcours, le batch fetch peut encore hydrater leurs
assets au passage. Les voyages ont le même parcours par ligne : `API-83`. **À ne pas défaire** :
une ligne de liste ne lit pas `getAssets()` pour sa miniature, et la miniature propre de la sortie
passe avant celle de son parcours, variantes claire et sombre comprises.
