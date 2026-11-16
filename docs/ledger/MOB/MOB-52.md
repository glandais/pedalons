---
id: MOB-52
title: "Météo : recette sur appareil de ce que `MOB-68` ne couvre pas"
status: open
size: "S"
group: "Recette sur une application qui tourne"
verified: 2026-11-16
---

## Reste à faire

`MOB-52` **Météo : recette sur appareil de ce que `MOB-68` ne couvre pas (S)** — la météo des
sorties de `MOB-51` a été refondue par `MOB-67` et `MOB-69`, puis par `MOB-134` : une seule
section Météo (`WeatherSection`) sur la page groupe, la sortie solo ou sans groupe et l'étape ;
`stage_weather_page.dart` et `stage_weather_card.dart` sont retirés, et avec eux les clés
`keys.ride.weather*` en double. Leur recette est celle de `MOB-135`. À trancher avec le
propriétaire : garder la ligne « Météo dès le … » (`NOT_YET_AVAILABLE`) sur les cartes du fil,
qui ajoute une ligne à toutes les sorties à plus de 7 jours (`RideWeatherSummaryLine.shows`).
