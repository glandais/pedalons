---
id: MIG-12
title: "L'ancien import biketeam"
status: done
done: 2026-09-28
---

## Livré

`MIG-12` **L'ancien import biketeam** a été supprimé le 2026-09-28 : seule la migration en direct
reste ([plan](../../plans/2026-09-22-biketeam-live-migration.md)), en service en staging et dont la mise
en production attend biketeam (§10 du plan, `MIG-1`) ; `biketeam_migration_map` sert encore au
direct, et les lignes `USER`, `USER_TEAM`, `COMMENT`, `…_PARTICIPATION` qu'écrivait l'import n'existent
plus en staging ni en prod (vérifié le 2026-09-29, bases reparties de zéro).
