---
id: MIG-17
title: "Supprimer les colonnes `dry_run` et `reset` de `biketeam_migrations`"
status: open
group: "Autour de la migration"
verified: 2026-11-16
---

## Reste à faire

`MIG-17` **Supprimer les colonnes `dry_run` et `reset` de `biketeam_migrations`** — plus rien
ne les lit ni ne les écrit depuis `MIG-16` (l'entité `BiketeamMigrationJob` ne les porte
plus) ; `V88__biketeam_migration_options_default.sql` leur a seulement donné un défaut, parce
que la version précédente, qui partage la base pendant un déploiement *rolling* et y revient
en cas de retour arrière, les écrit encore. À faire dans une version **ultérieure** à celle de
`MIG-16`, une fois celle-ci en production sans retour arrière possible : une migration Flyway
`alter table biketeam_migrations drop column dry_run, drop column reset`, et la requête de
[`MIGRATE_BIKETEAM.md`](../../MIGRATE_BIKETEAM.md) qui les mentionne. Taille : XS. Sans objet si
`MIG-8` retire la table avant.
