---
id: API-86
title: "Le tableau de bord d'équipe fermé aux visiteurs"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-86` **Le tableau de bord d'équipe fermé aux visiteurs** (2026-10-06, contrat `10.16.0`,
plan [Agenda d'équipe](../../plans/archive/2026-10-06-team-agenda.md) §3.3) — `TeamDashboardService` levait
403 pour tout non-membre et la ressource exigeait une connexion, si bien qu'un visiteur n'avait
que le fil. `TeamDashboardResource` est passée en `@PermitAll` (le 401 a quitté le contrat) et
`getDashboard` porte `@CheckAccess(TEAM, READ)`, la règle de `GET /api/teams/{slug}` : une
équipe `TEAM` répond 403 aux anonymes comme aux non-membres connectés, une équipe `PUBLIC` ou
`PUBLIC_UNLISTED` répond à tous, une équipe d'un autre domaine ou supprimée 404. Pour un
visiteur, `roleOf` renvoie `null` et `myUpcoming`, `latestAds`, `organizer` et `admin` ne sont
**pas calculés** ; `upcomingRides`, `latestPosts` et `newRoutes` sortent des mêmes
`listTeamSection`, donc des règles de `TeamEntityRepository` (seules les entités `PUBLIC`
publiées ou annulées, sans annonces ni contenu masqué par la modération). `TeamDashboardDto.role`
devient nullable ; le mobile masque le badge de rôle sans rôle. Version mineure malgré `role`
devenu nullable : le web et le mobile (hors stores) sont republiés avec le backend. Relecture
`security-reviewer` du 6 octobre 2026 sans problème : comportement 403/404 identique à la fiche
d'équipe (pas d'énumération en plus), pas de rôle intermédiaire qui passerait pour membre, rien
que les listes publiques (`PUBLICATION LIST`, `ROUTE LIST`) n'exposent déjà, réponse en
`Cache-Control: private, no-store`, coût fixe par visiteur. Couvert par
`TeamDashboardResourceTest` (`anonymous_shouldGetThePublicPart`, `nonMember_shouldGetThePublicPart`,
`formerMember_shouldGetThePublicPartOnly`, `visitor_shouldNotSeeWhatIsNotPublic`,
`membersOnlyTeam_shouldStayClosedToVisitors`, `privateTeam_member_shouldGetIt_outsiderNot`) et
`TeamDashboardQueryCountTest` (`dashboard_asNonMember_costDoesNotScaleWithTheTeam`,
`dashboard_anonymously_costDoesNotScaleWithTheTeam`).
**À ne pas défaire** : l'accès suit `TEAM READ`, jamais une règle propre au tableau de bord ;
les blocs réservés aux membres ne sont pas construits pour un visiteur (pas calculés puis vidés) ;
les sections publiques passent par les mêmes requêtes que les listes d'équipe ; la réponse reste
`private, no-store`, puisque son contenu dépend de l'appelant.
