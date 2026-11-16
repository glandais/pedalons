---
id: API-76
title: "Météo des voyages, étape par étape : `getTripWeather` (contrat `10.11.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-06
---

## Livré

### `API-76` Météo des voyages, étape par étape : `getTripWeather` (contrat `10.11.0`)

Livré le 6 octobre 2026 (10.10.0 → 10.11.0, mineur, ajouts seulement), sur les briques de `API-74`
et le §6 du plan [`2026-10-05-weather.md`](../../plans/archive/2026-10-05-weather.md). Constat préalable :
`TripStage.dateTime` est un vrai instant de départ (l'éditeur saisit date **et** heure ; une étape
migrée de biketeam reçoit l'heure de rendez-vous du voyage ou 8 h), donc aucun fuseau n'entre en jeu.
`GET /api/teams/{teamSlug}/trips/{tripSlug}/weather` (`getTripWeather`, `@CheckAccess(TRIP, READ)`,
mêmes en-têtes de cache que `getRideWeather`) rend un `TripWeatherDto` : une `TripStageWeatherDto`
par étape vivante, dans l'ordre de `TripDto.stages` (`stageId`, `leg` : `WeatherLegDto` du parcours
de l'étape à sa vitesse `averageSpeed` (`API-81`) ou 25 km/h, `summary` : `RideWeatherSummaryDto`
d'une ligne pour sa carte) ; un voyage sans étape a une seule entrée sans `stageId`, sur son propre
parcours. Chaque étape a **son** statut : partie → `OUT_OF_RANGE`, au-delà de 7 jours →
`NOT_YET_AVAILABLE` avec `WeatherLegDto.availableFrom` (champ nouveau, générique), sans parcours →
`NO_LOCATION`. Le statut global ne compte que les étapes à venir avec parcours dans l'horizon
(`RideWeatherCalculator.trip`) ; brouillon ou annulé → `OUT_OF_RANGE`. Pas de bloc « départ » : le
premier point du parcours est le départ. `WeatherPlanner` demande aussi les mailles des étapes
partant dans `[now, now+7 j]` (`TripStageRepository.findForWeather`) et des voyages sans étape
(`TripRepository.findStagelessForWeather`), via `TripWeatherPlans`, que la lecture
(`TripWeatherService`) partage. Au passage : lecture du cache extraite dans `WeatherSeriesLoader`,
ETag dans `WeatherEtag`, communs aux sorties et aux voyages. Tests (lancés, verts : `API-75`) : `TripWeatherResourceTest`, cas `trip_*` et `legSummary_*` de
`RideWeatherCalculatorTest`, `plan_shouldPlanTheStagesOfPublishedTripsLeavingInTheWindow` de
`WeatherPlannerTest`.

**À ne pas défaire** :
- Une étape partie reste dans la liste (`OUT_OF_RANGE`) : la liste suit `TripDto.stages` un pour un,
  les clients apparient par `stageId`.
- Le nombre de requêtes ne dépend pas du nombre d'étapes (traces, mailles, heures : une chacune) ;
  les heures sont lues sur une seule fenêtre couvrant les étapes dans l'horizon, bornée à ~7 jours.
- `RideWeatherSummaryDto.rainAlert.distance` est absente sur une sortie, présente sur une étape.
- Le résumé dans `TripDto` pour les cartes de liste n'est **pas** fait : c'est `API-82`.
