---
id: MOB-57
title: "Météo des étapes de voyage au mobile"
status: done
group: "Météo des sorties"
done: 2026-10-06
---

## Livré

`MOB-57` **Météo des étapes de voyage au mobile** (6 octobre 2026, contrat `10.11.0`, `API-76`).
`TripRepository.getTripWeather` et `tripWeatherProvider` (`FutureProvider.autoDispose.family` par
`TripKey`). L'écran 24 apparie `stages[].summary` aux étapes par `stageId` et affiche
`RideWeatherSummaryLine` sur chaque `StageCard`. L'écran 25 montre `StageWeatherCard` sous le bloc
date et lieux (état propre de l'étape : badge ancien, date d'ouverture, « Réessayer »,
`NO_LOCATION` aux seuls organisateurs, rien pour `OUT_OF_RANGE`), qui pousse `StageWeatherPage`
(`Navigator.push`, le seul leg de l'étape, sans sélecteur de groupe ni bloc départ). Les sections
de `ride_weather_page.dart` sont sorties dans `weather_leg_sections.dart` et les cartes de
`ride_weather_card.dart` rendues génériques (`WeatherForecastCard`…), partagées par les deux.
Pull-to-refresh : le détail de voyage recharge aussi la météo ; l'écran 25 en a gagné un. Aucun
appel pour un voyage terminé ou annulé. Clés `trips.weather.*` (fr, en). Test :
`trip_weather_test.dart`. Un voyage sans étape (une entrée sans `stageId`) n'affiche rien.
