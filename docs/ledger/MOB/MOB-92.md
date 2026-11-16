---
id: MOB-92
title: "La météo sur la carte du groupe, palier 2 : les pastilles aux checkpoints"
status: done
---

## Livré

`MOB-92` **La météo sur la carte du groupe, palier 2 : les pastilles aux checkpoints** (25
octobre 2026, contrat inchangé) — en plein écran et en mode Météo seulement, une pastille compacte
par checkpoint (ciel, température, flèche du vent absolue) et une goutte au point `rainAlert` ; un
toucher ouvre une `PdlSheet` courte (heure de passage dans la zone de la sortie, pluie en % et en
quantité, vent, rafales seulement quand le modèle en donne). `core/pdl` gagne des marqueurs
génériques (`PdlMapMarker`, cible de 44 px, égalité de valeur, couche `WidgetLayer` interactive à
part de celle des bornes) et `PdlMapBearing`, le cap de la carte. Placement par
`pointsAtDistances` sur la distance chaînée du palier 1. Le crédit Open-Meteo descend de
`RideWeatherDto.attribution` jusqu'à la légende, encastrée et plein écran. Le test resté ouvert du
palier 1 (puce « Météo » selon le statut, éteinte par défaut) est écrit. Plan [`2026-10-24-weather-on-map.md`](../../plans/archive/2026-10-24-weather-on-map.md).
Couvert par `ride_weather_map_markers_test.dart`, `pdl_map_marker_test.dart`,
`ride_groups_map_wind_test.dart`, `ride_group_page_test.dart`, `ride_weather_map_test.dart`.
**À ne pas défaire** : la flèche retranche le cap de la carte (`windArrowOnMap`), la rotation à
deux doigts étant active en plein écran ; seules les positions sont mémorisées, les libellés se
reconstruisent (langue, 12 h / 24 h) ; pas de pastilles sur la carte encastrée. La suite est
`MOB-93`.
