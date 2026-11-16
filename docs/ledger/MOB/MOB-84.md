---
id: MOB-84
title: "Points de parcours dans l'app, consultation (20 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-20
---

## Livré

### `MOB-84` Points de parcours dans l'app, consultation (20 octobre 2026, contrat d'API inchangé)

`MOB-84` **L'app montre les points de parcours d'auteur** — C3f de `WEB-100`, sur le contrat
`11.16.0` (C3c) et l'extension générée `WaypointTypeTone`. Partout où l'app montre la carte et le
profil d'un parcours : fiche parcours, étape de voyage (`EmbeddedRouteSheet`), plein écran de
`RouteMap`, sortie (`RideGroupsMap` sur le parcours du groupe sélectionné, `RideElevationSection`).
- **Carte** : `PdlMap.waypoints` (`PdlMapWaypoint`, sans DTO) en couches natives posées par
  `PdlMapController._addWaypointLayers` — halo (le point allumé), pictogrammes `symbol` typés
  (disque, anneau blanc, glyphe Material dessinés sur `PictureRecorder` à 3×, `icon-size` 1/3),
  noms en `symbol` aussi, à partir du zoom 12, collisions par `symbol-sort-key`. Points hors tracé
  compris. Toucher : `waypointKeyAt` (`featuresInRect`) puis la feuille `WaypointDetails`
  (`PdlSheet`) ; le toucher s'arrête là, ni tracé ni masse ni réticule. Le point reste allumé tant
  que la feuille est ouverte.
- **Profil** : repères (`PdlProfileMarker`, `ElevationMarkersPainter`, un `RepaintBoundary` entre
  l'aire et le réticule) pour les seuls points sur le tracé ; le toucher d'un repère ne vaut que
  dans la bande haute de 44 px, à 22 px près (E12), ailleurs le réticule garde le toucher.
- **Liste** `RouteWaypointsSection` (« Points du parcours »), triée par distance, hors tracé à la
  fin (« Hors tracé »), repliée au-delà de 10 lignes ; toucher une ligne centre la carte (la fiche
  parcours ramène d'abord la feuille au cran médian ; sur l'étape et la sortie, la vignette est
  ramenée à l'écran par `Scrollable.ensureVisible`).
- **État** : `WaypointSelectionController` (notifieur du `State`, comme le réticule) ; sur une
  sortie, `rideWaypointSelectionProvider`. Clés calculées une fois sur la liste d'origine
  (`waypointKey` : l'`id`, sinon `i<rang>`), partagées par carte, profil et liste.
- **Couleurs et icônes** : disque `WaypointTypeMarker.markerDisc` (teinte claire dans les deux
  thèmes, comme `TrackSurface`), glyphe foncé si la luminance dépasse 0,3 (règle du web) ; jeton
  `mapWaypoint` (ambre) remplacé par `mapWaypointRing` (blanc). 12 `PdlIcons.waypoint*` en
  Material, aucune dépendance ajoutée.
- **i18n** : `routes.waypoints.*` fr/en. **Ne pas défaire** : un seul jeu d'images reposé à
  chaque pose (un changement de fond efface les images du style) ; pas de `text-field` (les noms
  sont des images) ; jamais de filtre sur la valeur des coordonnées (`WEB-108`) ; un point hors
  tracé n'est jamais sur le profil ; pas de regroupement ; le client retrie par distance ; un type
  inconnu se rend comme `INFO` ; `PdlSheet` reste le seul appelant de `showModalBottomSheet`.
- **Écarts au web et à l'étude** : E1 Material et non Tabler ; E2 pas d'`addImageFromIconData`
  (glyphe nu, flou) ; E3 règle du glyphe = celle du code web (`BRANDING` §3.6 corrigé) ; E4 disque
  en teinte claire, liste et feuille en aplat du thème ; E5 noms en couche `symbol` et non
  `WidgetLayer` ; E6 feuille au toucher, pas de survol ; E7 sortie : les points du groupe
  sélectionné ; E8 plein écran sans liste ni profil ; E9 distance dans l'unité choisie ; E10 les
  bornes kilométriques restent au-dessus des pictogrammes ; E11 `PdlMap.didChangeDependencies`
  réinjecte les couleurs au changement de thème ; E12 bande haute du profil ; E13 pas de nom sous
  l'info-bulle du profil (`MOB-85`) ; E14 jeton `mapWaypointRing`. Hors périmètre : carte et
  profil globaux d'un voyage, masse de parcours, annonces.
- **Tests** : `route_waypoints_test.dart`, `waypoint_marker_colors_test.dart`,
  `pdl_map_controller_test.dart` (pile, images, GeoJSON `[0, 45]`, halo, rechargement),
  `pdl_waypoint_mark_test.dart`, `elevation_profile_test.dart` (`markerAt`, toucher d'un repère,
  glissement), `route_waypoints_section_test.dart`, `waypoint_sheet_test.dart`,
  `map_tap_target_test.dart`, `embedded_route_sheet_test.dart`, `ride_elevation_section_test.dart`.
  Reste la recette sur appareil : `MOB-86`.
