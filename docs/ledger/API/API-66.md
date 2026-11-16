---
id: API-66
title: "Compteurs d'activité sur `TeamDetailDto` (contrat `10.6.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-03
---

## Livré

### `API-66` Compteurs d'activité sur `TeamDetailDto` (contrat `10.6.0`)

Livré le 3 octobre 2026 (10.5.2 → 10.6.0, mineur, rétrocompatible) : `upcomingTripCount` (voyages
commençant à partir de maintenant) et `recentPostCount` (publications PUBLISHED datées dans
[maintenant − 7 j, maintenant]), sous les règles de visibilité, à 0 quand le module est coupé. Ils
nourrissent la ligne d'activité de « Mes équipes » (`WEB-42`, `MOB-42`). Tests (`TeamStatsResourceTest`) :
`getTeam_shouldCountUpcomingTripsAndRecentPosts`, `getTeam_admin_shouldNotCountADraftPostAsRecent`,
`listMyTeams_shouldCarryTheActivityCounters`, `getTeam_disabledModules_shouldCountNothing` ;
`TeamListQueryCountTest` (requêtes constantes pour `GET /api/teams?minRole=MEMBER` et anonyme) ;
aide `TestDataService.setTeamModules`. **À ne pas défaire** : les compteurs sont chargés par page
dans `TeamStatsRepository.load` (4 requêtes d'agrégat, jamais par ligne), via
`TeamEntityRepository.getPedalonsQuery` qui apporte les filtres domaine, visibilité, module et
suppression ; `recentPostCount` ne compte jamais un brouillon, même pour un admin ;
`RECENT_POST_WINDOW` = 7 jours.
