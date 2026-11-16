---
id: API-82
title: "Météo des voyages sur les cartes de liste (contrat `10.13.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-06
---

## Livré

### `API-82` Météo des voyages sur les cartes de liste (contrat `10.13.0`)

Livré le 6 octobre 2026 (10.12.0 → 10.13.0, mineur : un champ optionnel), reste de `API-76`.
`TripDto.weather` (`RideWeatherSummaryDto`, optionnel) porte la ligne météo d'une carte de voyage :
celle de sa **prochaine étape** — la première étape vivante partant à `now` ou après (par date, puis
rang), sinon le voyage lui-même s'il n'a pas d'étape. `TripWeatherLookup.forTrips` la calcule pour
toute la page dans `PublicationService.list` : **aucune** requête quand aucun voyage de la page n'a
d'étape restant à partir (brouillon, annulé, dernière étape partie — lu dans le `TripListSummary`
déjà chargé), **une** sinon (`WeatherHourlyRepository.findTripNextLegHours`), sans charger les
étapes : la prochaine étape, sa maille de départ et sa fenêtre (départ → départ + distance du
parcours à sa `averageSpeed`, 25 km/h à défaut) sont écrites en SQL. La maille de départ est celle
que le détail lit pour le premier point de contrôle de l'étape : premier point de la première trace
non vide du parcours, **avec** sa tranche d'altitude (aucune si la trace n'a pas d'altitude) — la
maille que le planificateur rapatrie déjà ; une étape sans parcours ne donne rien (`NO_LOCATION` au
détail). Au-delà de 7 jours, `NOT_YET_AVAILABLE` avec `availableFrom`. Absente sur la fiche du voyage
(`getTripWeather` y suffit). Résultat dans `RideWeatherSummaries` (nouvelle méthode `forTrip`).
Web : `PublicationCard` rend `RideWeatherSummaryLine` pour `TRIP` comme pour `RIDE`. Mobile :
`_TripBody` de `publication_card.dart` passe `trip.weather` au `RideWeatherSummaryLine` de la carte
de sortie (ni voyage terminé, ni annulé). Tests :
`PublicationQueryCountTest.listTeamTrips_inTheForecastWindow_weatherCostsAPageNotARow` (30 voyages dont la 1ʳᵉ étape est partie
et la 2ᵉ part demain : chaque carte `OK` à 14 °C, coût plat entre 3 et 30 lignes), mobile
`ride_card_weather_test.dart` (carte de voyage, terminée, annulée).

**À ne pas défaire** :
- Une requête par page au plus, jamais une par voyage, et jamais `trip.getStages()` sur une ligne de
  liste : un échec de `PublicationQueryCountTest` se corrige dans `TripWeatherLookup` / le SQL.
- La maille lue est celle du premier point de la trace, tranche d'altitude comprise : une maille sans
  tranche (comme pour le point de rendez-vous d'une sortie) n'est jamais rapatriée pour une étape, la
  ligne resterait vide.
- Le chemin JSON de `jsonb_path_exists` passe en paramètre : son `?` littéral serait lu comme un
  paramètre JDBC.
- Comme pour une sortie, les extrêmes sont ceux d'une seule maille (le départ) et l'alerte pluie n'a
  pas de `distance` ; la ligne de l'étape elle-même (`getTripWeather`) reste la référence.
