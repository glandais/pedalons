---
id: MIG-13
title: "Une équipe migrée naît avec le planificateur d'itinéraire"
status: done
done: 2026-09-29
---

## Livré

`MIG-13` **Une équipe migrée naît avec le planificateur d'itinéraire** (2026-09-29,
`BiketeamMigrationService.createTargetTeam`) — `enableRoutePlanner` restait à `false` ; il est
maintenant `true`, à côté de `addMemberAllowed` et `visibilityEditable` (déjà `true`). `joinable`
garde sa règle : toute visibilité sauf `TEAM`. À la création seulement : un rejeu ne touche pas
aux réglages Pédalons, et les équipes déjà migrées n'ont pas été rattrapées. Pas de changement de
contrat. Couvert par `BiketeamLiveMigrationTest.firstRun_createsTheTeam_…` (`TeamFlags`).
