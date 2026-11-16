---
id: API-78
title: "`DeviceRouteService.computeRideStartInstant` ne convertissait rien"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-78` **`DeviceRouteService.computeRideStartInstant` ne convertissait rien** (2026-10-06, pas
de changement de contrat) — la méthode cherchait le fuseau du départ du parcours (un appel à
`TimezoneService`) pour faire `ride.getDateTime().atZone(zone).toInstant()`, qui rend l'instant
reçu. Le défaut n'était qu'apparent : `Ride.dateTime` est un `Instant` absolu, et les deux apps le
lisent comme tel — Karoo (`MainActivity.formatDateTime`) fait `Instant.parse` puis l'affiche dans
le fuseau de l'appareil, Garmin (`FormatUtils.parseIsoDateTime`) construit un `Gregorian.moment`
en UTC que `Gregorian.info` rend à l'heure locale ; le tri des sorties par proximité de « maintenant »
compare aussi des instants. La méthode et l'injection de `TimezoneService` sont supprimées,
`startDateTime` reçoit `ride.getDateTime()` tel quel. Couvert par
`DeviceRoutesResourceTest.getRoutes_rideStart_isTheRideInstantUnshifted` (parcours à Nantes,
sortie à 7 h 30 heure de Paris, un groupe à 9 h : l'instant rendu est celui de la sortie, ni
décalé, ni remplacé par celui du groupe). L'heure propre de chaque groupe sur les appareils est
`API-84`. **À ne pas défaire** : `startDateTime` est un instant absolu, jamais relu au fuseau du
lieu de départ — c'est l'appareil qui le rend à son heure locale ; seule une heure **sans fuseau**
(le `LocalTime` d'un `RideGroup`) se lit au fuseau du départ, par `RideWeatherCalculator.legStart`.
