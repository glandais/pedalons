---
id: OPS-1
title: "Les migrations s'appliquent sur la base de prod, et le schéma qu'aucun test ne construit est le bon"
status: done
done: 2026-10-16
---

## Livré

`OPS-1` **Les migrations s'appliquent sur la base de prod, et le schéma qu'aucun test ne
construit est le bon** (2026-10-16, recette sur l'hôte, contrat inchangé) — les tests construisent
le schéma en `drop-and-create` depuis les mappings JPA, sans Flyway : un test vert ne prouve pas
qu'une migration passe sur une base existante. En prod, `flyway_schema_history` porte V69, V70 et
V71 (`gps_route_autosync`, la dernière du dépôt, appliquée le 16 octobre à 09:29) en
`success = t`, après V67 vu passer le 7 octobre (`OPS-29`, lot 5 d'`API-60`). Contrôles du
schéma, en lecture seule : la table `ad_contacts` existe ; `users.contactable_by_members` et
`ride_groups.leader_id` sont nullables ; la FK `ride_groups_leader_id_fkey` est en
`ON DELETE SET NULL` (`confdeltype = 'n'`) ; l'index partiel `idx_ride_groups_leader … WHERE
leader_id IS NOT NULL` existe ; `teams.enable_member_directory` est `NOT NULL DEFAULT false` ;
`uk_team_invitations_pending` est bien partiel (`WHERE status = 'PENDING'`) — l'objet que les
mappings JPA ne savent pas exprimer. Pas de test automatisé (recette sur l'hôte) ; la mise en
garde reste vraie et elle est écrite dans `backend/CLAUDE.md` (« Tests use `drop-and-create` (no
Flyway) »). **À ne pas défaire** : la FK de `leader_id` en `SET NULL`, jamais `CASCADE` (supprimer
un membre ne doit pas supprimer les groupes qu'il menait) ; l'index d'invitation en attente reste
partiel, sans quoi une invitation déclinée ou expirée interdit d'en renvoyer une.
