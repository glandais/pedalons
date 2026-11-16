---
id: SEC-15
title: "Reliquat V2 (comptes rattachés par l'ancien import biketeam) : sans objet"
status: done
done: 2026-09-29
---

## Livré

`SEC-15` **Reliquat V2 (comptes rattachés par l'ancien import biketeam) : sans objet**
(2026-09-29) — vérifié en staging et en prod : aucun compte venu de l'import (ni adresse factice,
ni compte non vérifié, aucune ligne `USER` dans `biketeam_migration_map`) ; les bases sont
reparties de zéro depuis l'import par dump, retiré par `d93fd3af`. Même constat que `LEGAL-1`.
