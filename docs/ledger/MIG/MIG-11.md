---
id: MIG-11
title: "Javadoc de `isPlaceholderLogo` corrigée"
status: done
done: 2026-09-30
---

## Livré

`MIG-11` **Javadoc de `isPlaceholderLogo` corrigée** (2026-09-30, `BiketeamMigrationService`) —
elle citait encore « 70 of the 187 exported teams », un décompte du dump de 2026-07 que l'import
live n'a plus ; elle dit seulement que beaucoup d'équipes n'ont jamais remplacé l'image par
défaut, comme [`MIGRATE_BIKETEAM.md`](../../MIGRATE_BIKETEAM.md). Pas de test (commentaire).
