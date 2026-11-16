---
id: WEB-67
title: "Météo des étapes de voyage au web"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-06
---

## Livré

`WEB-67` **Météo des étapes de voyage au web** (6 octobre 2026, contrat `10.11.0`, `API-76`).
`useGetTripWeather` est lu (et préfetché en phase 1, `TRIP_WEATHER_REQUEST` sans toast) par
`useTripDetailData` et `useStageDetailData`. La page d'étape montre `StageWeatherSection` sous un
`ErrorBoundary variant="inline"`, entre l'en-tête et le parcours : l'état propre de l'étape
(badge `STALE`, date d'ouverture, « Réessayer », `NO_LOCATION` aux organisateurs seulement, rien
pour `OUT_OF_RANGE` ni un statut inconnu) puis `LegWeather` libellé pour une étape. Chaque
`TripStageCard` du détail de voyage porte `RideWeatherSummaryLine` nourrie par
`stages[].summary`. `LegWeather` et `WeatherAttribution` sont sortis de `RideWeatherSection` pour
être partagés. `invalidateTripWeather` suit chaque invalidation du voyage (statut, édition).
Clés `trips.weather.*` (fr, en). Test : `StageWeatherSection.test.tsx`.
