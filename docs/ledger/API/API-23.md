---
id: API-23
title: "`updatedAt` en liste + `?updatedSince=`"
status: open
size: "M"
group: "Cache, fraîcheur et images — quatre briques indépendantes"
verified: 2026-11-16
---

## Reste à faire

`API-23` **`updatedAt` en liste + `?updatedSince=` (M)** — c'est ce qui rend une synchro
incrémentale possible. **À décider avant de coder** : `updatedSince` ne dit rien des
suppressions. Soit des tombstones (`deleted_at` interrogeable), soit une resynchronisation
périodique complète.
