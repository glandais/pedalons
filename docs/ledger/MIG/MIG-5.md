---
id: MIG-5
title: "Une équipe migrée ne se supprime plus"
status: done
done: 2026-09-30
---

## Livré

`MIG-5` **Une équipe migrée ne se supprime plus** (2026-09-30, API `7.1.0`) — `DELETE
/api/teams/{slug}` mettait à la corbeille une équipe basculée depuis biketeam, qui aurait alors
redirigé ses anciennes adresses vers des 404. `TeamService.delete` refuse désormais toute équipe
qu'une ligne `TEAM` de `biketeam_migration_map` désigne (`BiketeamMigrationMapRepository.isMigratedTeam`),
en 400 `MIGRATED_TEAM`, **à tout le monde, admins de plateforme compris** (décision du
30 septembre 2026). La seule issue est d'annuler la bascule sur biketeam : son reset met l'équipe
à la corbeille lui-même (`BiketeamLiveMigrationWorker`), sans passer par `TeamService`. La garde
est dans `delete(Team)`, donc elle couvre aussi l'effacement de compte, qui écartait déjà ces
équipes (`SOLE_MIGRATED_TEAM_ADMIN`). Le web affiche le message du code dans son bandeau d'erreur
; le mobile ne supprime pas d'équipe mais a la traduction. Couvert par `TeamResourceTest`
(`deleteTeam_migratedFromBiketeam_isRefusedToItsAdmin_andTheTeamStays`,
`deleteTeam_migratedFromBiketeam_isRefusedToAPlatformAdminToo`), **écrits sans avoir été
lancés**. Ne pas ajouter d'échappatoire pour un admin plateforme : c'est la bascule qu'il faut
annuler, pas l'équipe qu'il faut supprimer.
