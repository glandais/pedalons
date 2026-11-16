---
id: MOB-42
title: "Accueil membre : « Cette semaine », « Mes équipes », envoi vers l'appareil"
status: done
group: "Accueil membre"
---

## Livré

`MOB-42` **Accueil membre : « Cette semaine », « Mes équipes », envoi vers l'appareil** (3 octobre
2026, **API 10.6.0**). « Cette semaine » (`weekEventsProvider` : un `GET /api/calendar/events`,
aujourd'hui 00:00 → +7 jours dans le fuseau d'affichage, événements finis retirés, prochaine
sortie exclue, 5 lignes au plus, « rien d'autre » quand elle est seule) ; « Mes équipes »
(`myTeamsProvider`, badge de rôle via `TeamRoleTone`, ligne d'activité depuis `upcomingRideCount`
/ `upcomingTripCount` / `recentPostCount` sans les zéros, repli `teams.membersList.count`,
« Trouver une équipe » seulement si `ConfigDto.singleTeam == false`) ; action d'envoi sur « Ma
prochaine sortie » (parcours du groupe, sinon de la sortie ; `pickGpsService` /
`uploadRouteToService`). L'écran de connexion ouvre `/fonctionnalites` du site
(`openWebPage(Paths.features())`). Tests : `home_member_sections_test.dart`,
`login_discover_features_test.dart`, `link_launcher_test.dart`. **À ne pas défaire** : aucun appel
par équipe ni par événement, tout vient des listes ; `weekEventsProvider` est rechargé dans
`notifyParticipationChanged` et `refreshAfterReport` ; `features` est dans `webOnlyRouteIds`
(l'app n'a pas d'écran pour elle) ; `calendarEventTap` est partagé par `AgendaCard` et l'agenda
d'accueil.
