---
id: MOB-93
title: "La météo sur la carte du groupe, palier 3 lot A : la carte de l'onglet Météo"
status: done
---

## Livré

`MOB-93` **La météo sur la carte du groupe, palier 3 lot A : la carte de l'onglet Météo** (25
octobre 2026, contrat inchangé) — l'onglet Météo d'un groupe n'avait pas de carte. Une vignette
non manipulable en tête, **toujours en mode Météo** (tracé coloré, légende, crédit, sans puce ni
pastille), seulement si le leg a une prévision et le groupe un parcours ; un toucher ouvre le plein
écran de `RideGroupsMap` en mode Météo avec ses pastilles ; toucher un point de la frise pose un
curseur sur la carte à la distance chaînée (`pointsAtDistances`), le retoucher l'ôte.
`RideGroupsMap` gagne `forceWeatherMode` et `cursorDistance` ; `core/pdl` gagne `PdlMap.cursor`
(curseur déclaratif), `PdlMapHero.tapOpensFullscreen` et `PdlMapTapPassThrough` (zones que la
couche de toucher laisse passer, dont le ⓘ des crédits). Plan [`2026-10-24-weather-on-map.md`](../../plans/archive/2026-10-24-weather-on-map.md). Couvert par
`ride_group_page_test.dart` (carte selon le statut, curseur sur deux traces, plein écran, Aperçu
inchangé et une seule carte montée), `ride_groups_map_wind_test.dart`,
`pdl_map_hero_fullscreen_test.dart`, `trip_weather_test.dart`. **À ne pas défaire** : le mode
imposé de l'onglet ne lit ni n'écrit `rideMapWindModeProvider`, que `RideGroupPage` garde en vie
(`ref.listen` vide) pour que le choix de l'Aperçu survive au passage par l'onglet Météo ; le ⓘ des
crédits reste touchable au-dessus de la couche ; une ligne de frise non touchable n'a pas d'état
`selected` (`null`, pas `false`). La suite est `MOB-94`.
