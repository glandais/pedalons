---
id: MOB-82
title: "Revêtement sur la fiche embarquée d'une étape (20 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-20
---

## Livré

### `MOB-82` Revêtement sur la fiche embarquée d'une étape (20 octobre 2026, contrat d'API inchangé)

`MOB-82` **La fiche parcours d'une étape de voyage montre son revêtement** — l'écran 25
(`EmbeddedRouteSheet`) reprend la bascule Pente / Revêtement de `MOB-81` : `RouteSurfaceSection`
sous le profil, profil coloré par barre (`routeSurfaceBarsProvider`), ligne de la carte colorée
(`RouteMap.colorBy`), classe sous le réticule à la place de la pente. Les données y étaient déjà
(`getRouteDetail`). La mémoïsation des couleurs (`TrackSurfaceBarColors`) et l'infobulle
(`trackSurfaceTip`) passent de `route_detail_page.dart` à `route_surface_section.dart`, pour que
les deux fiches ne divergent pas. Test : `embedded_route_sheet_test.dart` (prêt, en cours, sans
revêtement) ; `flutter analyze` sans remarque. **Hors périmètre, décidé avec le propriétaire le
20 octobre 2026** : le profil global d'un voyage reste en pente seule ; le groupe d'une sortie a
sa bascule depuis (`MOB-83`). La fiche embarquée ne relance pas le calcul en cours (pas de
`ElevationRefreshPoller`, comme pour l'altitude provisoire).
