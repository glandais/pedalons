---
id: API-13
title: "Tri de l'annuaire des équipes"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-13` | **Tri de l'annuaire des équipes** (2026-09-30) — **API 5.12.0** : `GET /api/teams?sortBy=NAME\|MEMBER_COUNT&sortDir=ASC\|DESC`, sur le modèle des parcours et des annonces (`TeamSortBy`, `SortDirection`, DESC par défaut quand `sortBy` est donné). Sans `sortBy`, l'ordre historique (nom croissant). **La clé se termine toujours par l'id de l'équipe**, dans le même sens (`TeamRepository.orderClause`), y compris dans l'ordre par défaut qui ne l'avait pas : sans elle, deux équipes à égalité peuvent changer de place d'une page à l'autre, et la pagination par décalage en répète une et en saute une autre. `MEMBER_COUNT` trie sur la **même sous-requête corrélée** que le `memberCount` que portent les lignes — l'ordre correspond aux nombres affichés — dans l'unique requête de liste, sans compte par équipe. Le mobile (écran 34, découverte) demande `MEMBER_COUNT DESC` et rétablit la mention de la maquette, « 3 équipes · triées par nombre de membres » ; la requête et la mention lisent la même constante `kTeamDiscoverySort`. Le web n'annonçait aucun tri : rien à changer. Couvert par `TeamResourceTest.listTeams_sortByMemberCount_isTotalAcrossPages` (trois ex æquo départagés par l'id, page par page, puis ASC), `listTeams_withoutSort_keepsTheNameOrder`, `TeamMemberQueryCountTest.listTeams_sortedByMemberCount_costDoesNotScaleWithRowCount`, `team_repository_sort_test.dart` et `teams_discover_page_test.dart` | 34 |
