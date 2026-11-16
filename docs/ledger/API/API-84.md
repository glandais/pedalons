---
id: API-84
title: "Les appareils n'avaient que l'heure de la sortie, pas celle du groupe"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-84` **Les appareils n'avaient que l'heure de la sortie, pas celle du groupe** (2026-10-06,
contrat `10.14.0`) — `DeviceRideDto.startDateTime`, l'instant de la sortie, était la seule heure
de toutes ses entrées : Garmin (`RouteDetailView`) l'affichait sous le parcours d'un groupe parti
plus tard. Chaque `DeviceRideEntryDto` porte maintenant son `startDateTime`, un instant UTC
requis : pour un groupe qui a une heure, `RideWeatherCalculator.legStart` (l'heure du groupe lue
au fuseau du lieu de départ, sur la date locale de la sortie — la règle de `RideWeatherPlans`,
fuseau cherché au plus une fois par sortie, UTC sans lieu de départ) ; l'instant de la sortie pour
le parcours de la sortie elle-même et pour un groupe sans heure (`DeviceRouteService`). Karoo
(`DeviceRide.startOf`) et Garmin (`ApiClient.parseRideDto`) lisent le champ et retombent sur
l'heure de la sortie quand il manque (serveur antérieur à `10.14.0`) ; Karoo l'affiche sous le
nom du groupe dans la liste des entrées et sous le titre du parcours, Garmin sur l'écran du
parcours, par les deux chemins qui y mènent. La liste des sorties garde l'heure de la sortie.
Couvert par `DeviceRoutesResourceTest.getRoutes_entryStart_isTheGroupTimeAtTheDepartureZone`
(et `getRoutes_rideStart_isTheRideInstantUnshifted` pour l'heure de la sortie) ; aucun test côté
appareils (Karoo `assembleDebug` et Garmin `make build-all` sur les 13 appareils compilent, pas
d'essai sur appareil ni au simulateur). **À ne pas défaire** : `DeviceRideDto.startDateTime` reste
l'instant de la sortie (`API-78`) ; l'heure par entrée vient de `legStart`, jamais d'une
relecture de l'instant de la sortie au fuseau du départ ; les appareils rendent les deux à leur
heure locale.
