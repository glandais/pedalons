---
id: API-10
title: "Nom des montées"
status: done
group: "Petites évolutions d'API"
done: 2026-10-01
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-10` | **Nom des montées** (2026-10-01) — **API 9.3.0** : `ClimbDto.name`, nullable, le nom du **waypoint du parcours le plus proche du sommet de la montée, à 300 m au plus** (`ClimbNaming`, point du tracé le plus proche de `endDist`, distance haversine). C'est le nom que l'auteur du GPX a posé au col ; sans waypoint au sommet, pas de nom, et les clients gardent « Montée N ». **Tranché : pas de géocodage inverse** — un appel réseau par montée à chaque lecture (ou une colonne et son rattrapage), et le lieu le plus proche d'un sommet est souvent un hameau en contrebas ; un nom faux est pire que pas de nom. Calcul pur à la lecture, sur ce que le détail charge déjà (points du tracé, waypoints de la route) : aucune requête, aucune migration ; même règle sur l'aperçu GPX (`GpxPreviewDto`). Web : `RouteDetailView` rend le nom, l'infobulle du profil (`ElevationChart`) dit « *Nom* (i/n) : … » (`map.tooltip.climbNamed`). Mobile : `RouteClimbsSection`. Tests : `ClimbNamingTest` (sommet, plus proche gagnant, seuil, pied de montée, nom vide, `TrackDto.of`), `RouteResourceTest.getRoute_climbs_areNamedAfterTheWaypointAtTheirTop` (**écrit, non lancé** — fixe aussi l'ordre latitude/longitude du point PostGIS) ; `route_climbs_section_test.dart` | 13, 25 |
