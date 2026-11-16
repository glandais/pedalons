---
id: MIG-8
title: "Après l'arrêt de biketeam"
status: open
group: "Mise en production"
verified: 2026-11-16
---

## Reste à faire

`MIG-8` **Après l'arrêt de biketeam** : retirer la migration en direct (endpoints internes,
worker, les cinq variables, la page `biketeamMigration`, les codes `BIKETEAM_*`, peut-être
`biketeam_migrations`), **sans** retirer `biketeam_migration_map`, dont dépendent encore
`UserTeamRepository.findMigratedTeamsAdministeredAlone` (décision 22) et
`BiketeamTargetResolver`. Archiver alors le plan, qui reste jusque-là le contrat en vigueur.
