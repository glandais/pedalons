---
id: MOB-51
title: "Météo des sorties au mobile"
status: done
group: "Météo des sorties"
done: 2026-10-05
---

## Livré

`MOB-51` **Météo des sorties au mobile** (5 octobre 2026, contrat `10.9.0`, `API-74`).
`RideRepository.getRideWeather` et `rideWeatherProvider` (`FutureProvider.autoDispose.family` par
`RideKey`) nourrissent une carte compacte sous le bloc date et lieu du détail (groupe =
`selectedRideGroupProvider`) et l'écran « Météo du parcours » (`ride_weather_page.dart`, poussé
par `Navigator.push`, sans route au contrat) : sélecteur de groupe, départ avec lever et coucher
du soleil, étape (heures, vitesse et mention de la vitesse par défaut, vent dominant, alerte
pluie), exposition au vent (`PdlSegmentBar`), frise des points avec `PdlWindArrow` teintée par
`RelativeWind` et doublée d'un badge, attribution Open-Meteo.com. Une étape qui n'est ni `OK` ni
`STALE`, ou sans point, n'affiche qu'un bandeau `rides.weather.legUnavailable`. Le détail a gagné
un pull-to-refresh, qui recharge aussi la météo. `RideWeatherSummaryLine` est dans
`PublicationCard` (fil et fil d'équipe) et `NextRideCard`, avec une icône discrète pour `STALE`.
°C/°F dans `unit_system.dart`, `AppFormatters.formatTemperature` (sans « -0 »),
`formatTemperatureRange`, `formatPrecipitation`, `formatPercent`. Tests :
`ride_weather_display_test`, `ride_weather_page_test`, `ride_weather_summary_line_test`,
`ride_card_weather_test`, `pdl_weather_widgets_test`, les cas météo de `ride_detail_page_test`,
`unit_system_test`, `formatters_test`. **À ne pas défaire** : une seule table de rendu
(`features/rides/domain/ride_weather_display.dart`), qui passe chaque enum reçu par le `fromJson`
généré et omet une valeur inconnue ; `NO_LOCATION` n'est montré qu'aux organisateurs,
administrateurs d'équipe et de la plateforme (`canSeeWeatherNoLocation`) ; aucun appel pour une
sortie terminée ou annulée ; `PdlWindArrow` et `PdlSegmentBar` restent génériques (aucun DTO,
aucune traduction dans `core/pdl`) ; les précipitations restent en mm même en impérial ; pas de
teinte par condition (voir `WEB-60`). `RideCard`, d'avant la v2 et sans écran qui l'utilise, n'a
pas reçu la ligne de résumé.
