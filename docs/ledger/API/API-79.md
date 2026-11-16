---
id: API-79
title: "Tableau de bord d'équipe en un appel (contrat `10.8.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-06
---

## Livré

### `API-79` Tableau de bord d'équipe en un appel (contrat `10.8.0`)

Livré le 6 octobre 2026 (10.7.0 → 10.8.0, mineur, rétrocompatible) : `GET
/api/teams/{teamSlug}/dashboard` (`getTeamDashboard`, `@RolesAllowed("user")`, `Cache-Control:
private, no-store` ; 401 anonyme, 403 non-membre, 404 équipe inconnue) rend un `TeamDashboardDto` :
`team` (le `TeamDetailDto` de `GET /api/teams/{slug}`), `role`, les sections membre `myUpcoming`
(sorties et voyages à venir où l'appelant est inscrit, du plus proche au plus lointain, 3),
`upcomingRides` (sorties publiées à venir, 3), `latestPosts`, `newRoutes`, `latestAds` (3 chacune,
`null` quand le module est coupé), un bloc `organizer` (brouillons, sorties sans parcours, sorties
avec un groupe complet, signalements ouverts, modèles de sortie ; 5 chacun) et un bloc `admin`
(3 nouveaux membres, webhook), `null` en dessous du rôle requis. Un admin de plateforme non membre
reçoit le tableau ADMIN. Briques ajoutées pour le servir, utilisables seules : `sortDir` sur
`GET /api/teams/{slug}/publications` (pas sur `/count`, qu'un ordre ne change pas) ; filtres
`withoutRoute` (ni parcours sur la sortie ni sur aucun groupe) et `withFullGroup` sur la liste et le
compteur ; `RideDto.groupSummaries` (`RideGroupSummaryDto`, remplis aussi sur les lignes de liste,
sans meneur ni participants) et `distance` / `elevationGain` / `surfaceType` du parcours de la
sortie, sinon du premier groupe qui en a un ; `TeamDetailDto.memberCountByRole` (admin d'équipe ou
de plateforme, `null` sinon et dans les listes) ; `sortBy=JOINED_AT` + `sortDir` sur les membres
(départage par id). Tests : `TeamDashboardResourceTest` (14), `TeamDashboardQueryCountTest` (ADMIN,
ORGANIZER, MEMBER), `TeamPublicationFiltersResourceTest`, `RideListGroupSummariesTest`,
`TeamMemberCountByRoleResourceTest`, `TeamMemberSortResourceTest` — verts dans la suite complète
du 5 octobre 2026 (2 088 tests, 0 échec). **À ne pas défaire** : chaque section est une page bornée
construite par les services existants, avec leurs lookups par page — jamais une requête par ligne ;
les effectifs par groupe sortent de la requête groupée de `RideSummaryRepository.loadGroupCounts`,
les mesures du parcours de la même requête de résumé ; le sélecteur d'équipes, le compteur de
non-lues et le jeton de calendrier restent **hors** de l'agrégat (partagés avec le reste de
l'application) ; `upcomingRides` et les tuiles organisateur ne montrent que du PUBLISHED, alors que
`myUpcoming` garde une sortie annulée où l'on est inscrit ; « Prix à négocier » = `price` nul, sans
champ dédié (décidé le 5 octobre 2026 avec le propriétaire). Le test de coût du membre fait signaler
les publications par un compte non mesuré : la liste cache à l'appelant ce qu'il a signalé, et ses
sections resteraient vides.
