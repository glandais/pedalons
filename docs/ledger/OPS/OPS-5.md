---
id: OPS-5
title: "Le relais de contact n'est pas contourné"
status: done
done: 2026-10-16
---

## Livré

`OPS-5` **Le relais de contact n'est pas contourné** (2026-10-16, contrat `11.5.1`) — le `grep`
et le script Python du §5.3 du
[document d'API](../../plans/archive/2026-07-26-api-v2-livraison-et-suites.md), rejoués sur
`contracts/openapi.yaml`, sortent « AdDto: OK » : ses propriétés sont `adType`, `createdAt`,
`createdByDisplayName`, `createdById`, `deleted`, `excerpt`, `id`, `images`,
`locationDescription`, `locationGeometry`, `media`, `name`, `price`, `rentalPeriod`, `slug`,
`status`, `tags`, `team`, `thumbnailUrl`, `updatedAt`, `visibility` — ni contact, ni e-mail, ni
téléphone ; le contact passe par `POST /api/teams/{teamSlug}/classifieds/{slug}/contact`. Pas de
test automatisé : l'invariant ne vit que dans ce script et dans `CLAUDE.md`, d'où la tâche
`OPS-44`. **À ne pas défaire** : aucun champ de contact sur `AdDto`, jamais — un seul
publierait une adresse personnelle à toute une équipe, irrévocablement.
