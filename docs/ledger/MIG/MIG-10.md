---
id: MIG-10
title: "Javadoc de `contentVisibility` corrigée"
status: done
done: 2026-09-30
---

## Livré

`MIG-10` **Javadoc de `contentVisibility` corrigée** (2026-09-30, `BiketeamMigrationService`) —
elle disait que rabattre le `PUBLIC_UNLISTED` de l'équipe sur ses contenus ne changerait rien ;
elle dit maintenant que le fil de l'équipe se viderait, les listes limitées à l'équipe exigeant
`te.visibility = 'PUBLIC'`, comme [`MIGRATE_BIKETEAM.md`](../../MIGRATE_BIKETEAM.md). Le code n'a pas
changé : la visibilité d'un contenu vient de son propre `listed_in_feed`, jamais de celle de
l'équipe — ne pas la rabattre. Pas de test (commentaire).
