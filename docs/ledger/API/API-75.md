---
id: API-75
title: "Tests backend de la météo, lancés"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-06
---

## Livré

### `API-75` Tests backend de la météo, lancés

Lancés le 6 octobre 2026 : les 16 classes de la météo des sorties et des voyages
(`TripWeatherResourceTest`, `CellKeyTest`, `RouteSampleLookupTest`, `RideWeatherCalculatorTest`,
`WeatherRefreshPolicyTest`, `OpenMeteoGatewayTest`, `OpenMeteoClientTest`,
`OpenMeteoCircuitBreakerTest`, `OpenMeteoGatewayHttpTest`, `WeatherCacheTest`,
`WeatherFetchWorkerTest`, `WeatherPlannerTest`, `WeatherHousekeepingTest`, `RideWeatherResourceTest`,
`PublicationQueryCountTest`, `ArchitectureTest` : 166 tests) puis la suite complète (3 312 tests),
sans un échec ni correction : le SQL natif de V61 (upsert `NULLS NOT DISTINCT`, backoff, fenêtre de
la liste) tient sur la base de test. **À ne pas défaire** : un échec futur de
`PublicationQueryCountTest` se corrige dans `RideWeatherLookup`, jamais en desserrant le test.
