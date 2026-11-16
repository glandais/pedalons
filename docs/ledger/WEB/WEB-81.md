---
id: WEB-81
title: "GPX à plusieurs traces : profil empilé et synchro faussée (S, priorité basse)"
status: open
size: "S"
group: "Couverture e2e — ce que l'audit du 27 septembre laisse ouvert"
verified: 2026-11-16
---

## Reste à faire

`WEB-81` **GPX à plusieurs traces : profil empilé et synchro faussée (S, priorité basse)** —
la distance cumulée de chaque point (`p[3]`) repart à 0 à chaque trace
(`GpxProcessingService.toTrackPoints` reprend `path.getDist()` trace par trace ;
`RouteSampleLookup.chain` doit d'ailleurs ajouter un décalage pour les mettre bout à bout). Le
web aplatit les traces sans ce décalage (`ElevationChart.tsx`, `useMapChartZoomSync`, l'index
de survol de `RouteTrackMap`) : les profils s'empilent sur le même axe et une plage de
distances désigne plusieurs traces à la fois. Le mobile est à vérifier aussi
(`pdl_elevation_profile.dart`, `route_cursor_controller.dart`). Non reproduit sur un vrai
fichier, et aucun cas en prod : 0 parcours à plus d'une trace sur 5 527 au 16 octobre 2026.
L'import d'un fichier à plusieurs `<trk>` reste possible (`tracksAsPaths`). À trancher :
enchaîner côté client comme `RouteSampleLookup`, côté API (contrat), ou fusionner les traces
à l'import comme le fait déjà `GpxTrackMerger` (`API-112`) pour une fusion explicite.
`trackDistanceRange` traite déjà chaque trace à part (`WEB-80`).
