---
id: API-74
title: "Météo des sorties : cache Open-Meteo et `getRideWeather` (contrat `10.9.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-05
---

## Livré

### `API-74` Météo des sorties : cache Open-Meteo et `getRideWeather` (contrat `10.9.0`)

Livré le 5 octobre 2026 (10.8.0 → 10.9.0, mineur, ajouts seulement), d'après le plan
[`2026-10-05-weather.md`](../../plans/archive/2026-10-05-weather.md), qui garde les arbitrages détaillés. Le
backend tient un **cache global** en Postgres (`V61__weather_cache.sql` : `weather_cells`,
`weather_hourly`, `weather_daily`, tables nouvelles seulement) rempli en tâche de fond depuis l'API
forecast d'Open-Meteo : `WeatherPlanner` (toutes les 5 min, sans HTTP) déduit des sorties PUBLISHED
de `[now, now+7 j]` les mailles nécessaires (~5 km, `CellKey`, bande d'altitude de 100 m) et leur
passage le plus proche ; `WeatherFetchWorker` (toutes les minutes) les réserve
(`for update skip locked` + bail `claimed_until`) et les récupère par lots de 100 lieux, au centre de
la maille ; TTL de 1 h, 3 h ou 6 h selon la distance du passage (`WeatherRefreshPolicy`), backoff
`min(5 min·2^attempts, 1 h)`, 429 jusqu'à l'heure pleine suivante, coupe-circuit et budgets par jour
UTC, heure et minute glissantes (`OpenMeteoCircuitBreaker`) ; `WeatherHousekeeping` purge la nuit.
Une cellule n'est réservée que si le planificateur l'a demandée depuis moins de 20 min et que son
passage est à venir : une orpheline n'est plus jamais récupérée, seulement purgée.

`GET /api/teams/{teamSlug}/rides/{rideSlug}/weather` (`getRideWeather`, `@CheckAccess(RIDE, READ)`)
rend un `RideWeatherDto` : météo au départ (`DepartureWeatherDto`), une `WeatherLegDto` par groupe
(heure de départ du groupe lue à l'heure locale du point de départ, vitesse du groupe ou **25 km/h**
avec `speedIsDefault`, points tous les 15 km et l'arrivée, vent relatif segment par segment, exposition
en mètres, vent dominant, alerte pluie ≥ 50 %) et l'attribution Open-Meteo.com (CC BY 4.0). Toujours
200 hors 404, l'état dans `status` (`OK`, `STALE`, `NOT_YET_AVAILABLE` + `availableFrom`,
`UNAVAILABLE`, `NO_LOCATION`, `OUT_OF_RANGE`) ; `Cache-Control: private, no-cache` et ETag faible,
`no-store` sans ETag pour `UNAVAILABLE`. Les listes portent un résumé `RideDto.weather`
(`RideWeatherSummaryDto`, min → max sur la fenêtre départ → dernière arrivée estimée), chargé par
`RideWeatherLookup.forRides` dans `PublicationService.list` et `RideService.toDto`. Les enums
`WeatherStatus`, `WeatherCondition` (table WMO dans la description du schéma), `RelativeWind`,
`CompassPoint` et `WeatherCheckpointKind` sont dans `fr.pedalons.enums`. Tests (lancés le 6 octobre, verts :
`API-75`) : purs — `CellKeyTest`, `RouteSampleLookupTest`, `RideWeatherCalculatorTest`
(changements d'heure, vitesse par défaut, aller-retour), `WeatherRefreshPolicyTest`,
`OpenMeteoGatewayTest`, `OpenMeteoClientTest`, `OpenMeteoCircuitBreakerTest` ; `@QuarkusTest` —
`WeatherCacheTest`, `WeatherPlannerTest`, `WeatherFetchWorkerTest`, `WeatherHousekeepingTest`,
`OpenMeteoGatewayHttpTest` (vrai client sur un serveur local qui répond 429), `RideWeatherResourceTest`
(dont `weather_withAForecast_isOk_andCarriesNoCoordinate`) et
`PublicationQueryCountTest.listTeamRides_inTheForecastWindow_weatherCostsAPageNotARow`.

**À ne pas défaire** :

- **Cache global, sans `domainId`** : une ligne n'est fonction que de (maille, heure), et n'est lue
  qu'en partant d'une sortie que l'appelant a le droit de lire. C'est l'exception explicite à
  « toutes les requêtes filtrent par domainId », écrite dans la javadoc de `domain/weather` ; deux
  domaines au même départ partagent une cellule (`WeatherPlannerTest`).
- **Aucune coordonnée dans les DTO météo** : une sortie PUBLIC peut pointer sur un parcours TEAM.
  Les points se placent côté client par `distance` sur la géométrie lisible ; le fournisseur n'est
  interrogé qu'au centre de la maille, jamais au lieu de rendez-vous.
- **Tous les calculs côté serveur** (`RideWeatherCalculator`, fonctions pures) : heures de passage,
  échantillons, vent relatif, exposition, alerte pluie, rose des vents. Les clients n'affichent,
  ne traduisent et ne convertissent que les unités.
- **Jamais d'appel à Open-Meteo ni d'écriture en base pendant une requête HTTP** : la lecture ne
  touche que le cache, ce qui permet au SSR web de la préfetcher sans risque.
- La liste coûte **0 requête** si aucune sortie de la page n'est dans la fenêtre, **1** sinon
  (`WeatherHourlyRepository.findRideWindowHours`, tout en SQL natif) ; ne pas charger les groupes
  par ligne. Dans ce chemin l'heure locale d'un groupe se lit dans le fuseau rendu par Open-Meteo
  pour la maille (pas `TimezoneService`) : écart accepté en limite de fuseau.
- L'ETag est un condensé SHA-256 du corps (calculé dans `RideService`, rendu par
  `RideWeatherAnswer`), pas « version + `fetchedAt` » : modifier un groupe ne change pas la
  `version` de la sortie, et un passage en `STALE` non plus.
- Le client REST `open-meteo` a `disable-default-mapper=true`, et `OpenMeteoGateway` relit une
  `WebApplicationException` comme la réponse qu'elle porte : sinon un 429 passe pour un échec
  ordinaire. La clé (`OPEN_METEO_API_KEY`) part en paramètre de requête : l'URL n'est jamais
  journalisée.
- Une sortie partie, annulée ou en brouillon est `OUT_OF_RANGE` (fenêtre du planificateur alignée
  sur `[now, now+7 j]`) ; une étape sans parcours est `NO_LOCATION` sans compter dans le statut
  global ; une étape dont certains points manquent est `STALE`. Un échantillon à 5 km pile de
  l'arrivée est omis. À rouvrir ensemble si la lecture sert un jour les sorties en cours.
- Sur échec, rien n'est supprimé : on sert le cache périmé (`STALE` au-delà de deux intervalles de
  rafraîchissement).
