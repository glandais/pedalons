---
id: MIG-14
title: "Les tags de parcours biketeam sont importés"
status: done
done: 2026-10-01
---

## Livré

`MIG-14` **Les tags de parcours biketeam sont importés** (2026-10-01, API 10.1.0 ; détaché de
`MIG-6`, qui garde la ville et le pays ; plan archivé
[`2026-10-01-tags.md`](../../plans/archive/2026-10-01-tags.md) §7, D21) — à l'import d'un parcours,
`TagService.importTags` retrouve chaque libellé de `BtMap.tags` (trim, vides écartés) dans le
vocabulaire `ROUTE` de l'équipe, sans tenir compte de la casse, ou le crée en `GRAY` avec la
première graphie rencontrée, puis **remplace** les tags du parcours : un rejeu ne double ni tag ni
liaison, et un tag retiré sur biketeam quitte le parcours (il reste au vocabulaire). Au-delà des
bornes (D16) la migration n'échoue pas : un libellé de plus de 32 caractères est coupé (sur les
points de code — jamais au milieu d'une paire de substitution), au-delà de 10 tags sur le
parcours ou de 100 dans l'équipe les premiers sont gardés dans l'ordre de l'instantané, et
l'avertissement `TAGS_TRUNCATED` le dit. `defaultSearchTags` n'est ni exporté ni importé (D8).
Tests (verts le 1er octobre 2026) : `BiketeamLiveMigrationTest.routeTags_*` (fusion de casse,
rejeu, coupe et troncature avec un libellé non BMP, équipe à 100 tags). **À ne pas défaire** :
livré avant les bascules de production (D22) — aucun rattrapage n'est prévu pour une équipe
basculée avant.
