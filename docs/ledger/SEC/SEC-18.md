---
id: SEC-18
title: "Le filtre de rôle du trombinoscope révélait des rôles masqués"
status: done
done: 2026-09-30
---

## Livré

`SEC-18` **Le filtre de rôle du trombinoscope révélait des rôles masqués** (2026-09-30, **API
5.7.1**, hors audit) — relevé en livrant `WEB-1`. Quand la réponse masque les rôles (un lecteur
que `API-39` n'autorise pas à les voir), `GET /api/teams/{slug}/members` refuse désormais le
paramètre `role` par un 403 `FORBIDDEN` (`TeamMembershipService.getTeamMembers`), comme tout ce
que ce lecteur ne peut pas faire, au lieu de l'appliquer ; seuls la description du paramètre et
celle du 403 changent au contrat, d'où le correctif. Le filtre reste ouvert à qui reçoit les
rôles (admin d'équipe ou de plateforme, ou trombinoscope ouvert). Les deux clients ne le proposent
plus dans ce cas : le web ne l'affichait déjà pas (`TeamDirectoryPage`), le mobile masque ses
chips de rôle (`TeamMembersPage.rolesShown`). Couvert par
`TeamMembershipServiceTest.getTeamMembers_roleFilter_isRefused_whenTheRolesAreHidden` (refus,
et le même filtre accepté pour l'admin) et `getTeamMembers_roleFilter_works_onceTheDirectoryIsOpen`,
et côté mobile par `team_members_page_test.dart` (« sans les rôles, aucune chip de rôle »). Ne pas
remplacer le refus par un filtre ignoré en silence : un résultat filtré « pour rien » se lit comme
une réponse.
