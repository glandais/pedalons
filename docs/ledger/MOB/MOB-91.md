---
id: MOB-91
title: "La météo sur la carte du groupe, palier 1 : le vent sur le tracé"
status: done
---

## Livré

`MOB-91` **La météo sur la carte du groupe, palier 1 : le vent sur le tracé** (24 octobre
2026, contrat `11.16.1`) — la carte de l'Aperçu d'un groupe ne montrait rien de la météo. Une puce
« Météo » sous la carte encastrée (et un interrupteur « Vent sur le tracé » dans la feuille des
couches du plein écran, `PdlMapHeroSwitch` générique dans `core/pdl`) colore le tracé dos /
travers / face (`RelativeWindStroke.stroke`, nuance 6 de la table générée, dans les deux thèmes),
avec une légende en mots (`RideWindMapLegend`, parts de `windExposure`, « Prévision ancienne » en
STALE, vitesse par défaut). Distances : `chainedMeasures` (`features/rides/domain/ride_weather_map.dart`)
reprend la règle du serveur, saut nul entre traces ; `windSegmentColors` colore les intervalles
des lignes brutes. Plan [`2026-10-24-weather-on-map.md`](../../plans/archive/2026-10-24-weather-on-map.md). Couvert par `ride_weather_map_test.dart` (cas à deux traces
du fixture de `RouteSampleLookupTest`), `ride_groups_map_wind_test.dart` et
`ride_group_page_test.dart` (prévision perdue → mode éteint). **À ne pas défaire** : ne pas passer
par `PolylineIndex.fromLineStrings`, qui compte le saut entre traces à vol d'oiseau ; mode éteint
par défaut (`rideMapWindModeProvider`), éteint aussi quand un refetch perd la prévision
(`RideGroupPage`), pour qu'une prévision revenue ne recolore pas le tracé sans nouveau choix ; un
intervalle sans vent connu garde le trait du parcours, jamais le gris du travers. La suite est
`MOB-92`.
