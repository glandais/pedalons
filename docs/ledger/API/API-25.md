---
id: API-25
title: "`blurHash`"
status: open
size: "S"
group: "Cache, fraîcheur et images — quatre briques indépendantes"
verified: 2026-11-16
---

## Reste à faire

`API-25` **`blurHash` (S)** — 30 octets par image, calculés une fois à l'upload. Le seul point
à trancher : faire de `thumbnailUrl` un objet `{url, blurHash, width, height}` est un
**MAJOR** (changement de type sur un champ livré en 1.3.0) ; un champ frère
`thumbnailBlurHash` ne l'est pas. Pour les images existantes, le backfill par lots
d'`AssetMetadataBackfillScheduler` (`API-43`) est un schéma réutilisable.
