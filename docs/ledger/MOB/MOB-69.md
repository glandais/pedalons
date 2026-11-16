---
id: MOB-69
title: "Sortie à un seul groupe : le détail est la page du groupe"
status: done
group: "Météo des sorties"
done: 2026-10-13
---

## Livré

`MOB-69` **Sortie à un seul groupe : le détail est la page du groupe** (13 octobre 2026, contrat
inchangé ; même règle que `WEB-79`). Prédicats dans `domain/solo_group.dart` : `soloGroupOf`,
`leavesGroupPage` (`<= 1` groupe), `rideOwnLeg` (correspondance stricte du `groupId`). Morceaux
sortis de `RideGroupOverviewTab` : `RideGroupStats`, `RideGroupLeaderRow` (seulement si
`group.leader`), `RideGroupRouteActions`. Pour une sortie solo, `RideDetailPage` rend
`RideSoloGroupSection` à la place de `RideGroupsSection` (en-tête « Groupe X » à la couleur
`multiTrackColor(sortOrder)`, sans chevron ni tap ; bandeaux d'échec et d'export ; stats ;
meneur ; avatars qui ouvrent `ParticipantsSheet` ; actions du parcours) et pose
`RideGroupActionBar` en barre d'action (`onOpenGroup` nul : pas de « Voir mon groupe »). Un refus
de « Rejoindre » fait défiler jusqu'à son bandeau. `RideWeatherCard` déroule `rideOwnLeg`
(en-tête et corps du leg sous la carte départ), aussi pour une sortie sans groupe. `RideGroupPage`
quitte une fois (`_leaving`) quand `leavesGroupPage` : `pop` si le détail de la sortie est juste
dessous (lien profond reconstruit), sinon `pushReplacement`, `go` à froid ; `?tab=weather` fait
défiler le détail jusqu'à la météo (`ride_scroll_target_provider.dart`), `#meteo` n'est pas lu.
La capture `rideGroupWeather` d'une sortie solo devient un défilement du détail. Clés
`keys.ride.soloGroupSection`, `soloGroupHeader`, `soloGroupParticipants` ; module Patrol `ride`
adapté. Tests : `solo_group_test.dart`, `ride_detail_page_test.dart`,
`ride_group_page_test.dart` (dont un routeur imbriqué comme `router.dart` : le lien profond
`?tab=weather` revient au détail sans entrée d'historique) ; Patrol `ride_solo_group_test.dart`
(vert au 16 octobre 2026, comme `MOB-68`). **À ne pas défaire** : mêmes décisions que `WEB-79` (météo du
parcours sur le détail pour 0 et 1 groupe, aucun lien vers la page groupe d'une sortie solo,
remplacement sans entrée d'historique).
