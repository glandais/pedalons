---
id: OPS-15
title: "Restaurer MinIO sous une base plus récente : la marche à suivre écrite"
status: done
done: 2026-09-30
---

## Livré

`OPS-15` **Restaurer MinIO sous une base plus récente : la marche à suivre écrite** (2026-09-30) —
la section « Restoring » d'[`OPERATIONS.md`](../../OPERATIONS.md#restoring) dit qu'un volume MinIO
plus ancien que la base (une copie antérieure à la fin du rattrapage `API-43`) ramène des photos
avec leur EXIF que rien ne revisitera, et donne l'`UPDATE assets SET metadata_pending = true` qui
les remet dans le rattrapage. Précisé à l'écriture : **pas après une restauration ordinaire** —
`restore.sh` prend base et objets dans le même instantané, les drapeaux concordent, et chaque
passe est un réencodage avec perte. Les GPX se réparent seuls (le marqueur de
`GpxSanitizationBackfill` vit dans le bucket). Pas de test (documentation).
