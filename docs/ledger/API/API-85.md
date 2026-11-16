---
id: API-85
title: "Aucune heure de fin : « À venir » comparait le départ à maintenant"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-85` **Aucune heure de fin : « À venir » comparait le départ à maintenant** (2026-10-06,
contrat `10.15.0`, plan [Agenda d'équipe](../../plans/archive/2026-10-06-team-agenda.md) §3.1–3.2) — une
sortie partie depuis dix minutes ou un voyage commencé la veille sortaient de « À venir », le
calendrier et l'ICS envoyaient `end = null`. Colonne `team_entities.end_date_time` (V63,
nullable, index `(team_id, end_date_time)`), écrite par un seul service,
`PublicationEndCalculator` : sortie = le plus tard des groupes (départ du groupe lu par
`RideWeatherCalculator.legStart`, + distance de son parcours, à défaut celui de la sortie, à sa
`averageSpeed`) ; voyage = la plus **tardive** de ses étapes vivantes (chaque étape stocke aussi
la sienne) — décision : la plus tardive plutôt que la dernière triée, identiques sur un voyage
bien rangé, et la seule qui ne rend jamais « passé » un voyage dont une étape est encore devant ;
groupe ou étape sans vitesse ou sans parcours (supprimé compris), sortie sans groupe, voyage sans
étape : départ + `DEFAULT_DURATION` = 3 h. Recalculée à la création et à la modification d'une
sortie (`RideService`, gabarits compris : le client préremplit puis crée) et d'un voyage
(`TripService.updateTrip` porte ajout, modification, suppression et réordonnancement d'étapes), à
la publication programmée (`PublicationPublishScheduler`), au remplacement du GPX d'un parcours
(`RouteService.updateRoute` → `refreshUsersOf` : sorties, groupes et étapes qui le citent) et à
l'import biketeam (qui passe par les deux services). `PublicationEndBackfill` remplit au démarrage,
par lots de 200 et par mise à jour conditionnelle (`where end_date_time is null`, sans toucher à
la version), ce qu'un backend antérieur laisse nul ; les requêtes lisent la fin stockée, sinon
`date_time + 3 h`. `GET /api/teams/{slug}/publications`, `GET /api/publications` et leurs
`/count` acceptent `when=UPCOMING|PAST` (fin ≥ / < maintenant ; ne garde que sorties et voyages),
tri fixé par le serveur — départ croissant / décroissant —, `sortDir` prioritaire s'il est donné,
`participating=true` combinable. `RideDto.endDateTime` et `TripDto.endDateTime` (requis) ;
`CalendarEventDto.end` porte la fin de la sortie ou de l'étape, `finished` s'en sert ; l'ICS écrit
`DTEND` (une étape « journée entière » couvre chaque jour jusqu'à sa fin,
`IcsGenerationService.allDayEnd`). Le tableau de bord (« Mes prochaines », « Prochaines sorties »
et les tuiles organisateur) passe sur `notEndedAt(now)`. Couvert par
`PublicationEndCalculatorTest` (la règle), `PublicationEndStoredTest` (valeur relue en base à
chaque point d'entrée, et le remplissage), `PublicationPublishSchedulerTest.autoPublish_storesTheEndOfARideThatHadNone`,
`BiketeamLiveMigrationTest.importedRidesAndTrips_haveTheirEndStored`, `PublicationWhenFilterTest`,
`CalendarEventFieldsTest` (fin et `DTEND`), `IcsGenerationServiceTest.allDayEnd_coversEveryDayUpToTheEnd`,
`TeamDashboardResourceTest.aRideUnderWay_staysInTheUpcomingSections`. **À ne pas défaire** :
`PublicationEndCalculator` est le seul auteur de la colonne — tout nouveau chemin qui déplace un
départ, un groupe, une étape ou la longueur d'un parcours l'appelle ; les lectures gardent le repli
`date_time + DEFAULT_DURATION` (déploiement à chaud) ; le remplissage ne touche que les lignes
nulles et jamais la version. `RideDto.finished` reste « départ passé » (`API-16`) : la fin sert
aux listes, au calendrier et à l'ICS.
