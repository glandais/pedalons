---
id: MIG-9
title: "Purge physique des équipes à la corbeille"
status: open
group: "Autour de la migration"
verified: 2026-11-16
---

## Reste à faire

`MIG-9` **Purge physique des équipes à la corbeille** (reset de migration biketeam) — chantier
séparé. Un `reset` de la migration en direct mettait l'équipe Pédalons à la corbeille et
libérait son slug, rien de plus : lignes `team_entities`, assets et fichiers
S3 restent. Chaque reset en laissait un exemplaire de plus ; l'option est supprimée depuis le
11 novembre 2026 (`MIG-16`), il ne s'en crée donc plus, mais ceux qui existent restent. **Quand** : si le volume le
justifie, ou avec une politique de rétention générale de la corbeille. Décision du 2026-09-22
([plan](../../plans/2026-09-22-biketeam-live-migration.md) §13, décision 10). Le cas s'est produit
en production : au 16 octobre 2026, trois équipes y sont à la corbeille, dont la copie de
`n-peloton` laissée par le reset du 15 octobre, avec 3 328 lignes `team_entities` en tout, sans
compter les assets S3.
