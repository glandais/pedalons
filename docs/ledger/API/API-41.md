---
id: API-41
title: "Le meneur de groupe"
status: done
group: "Petites évolutions d'API"
---

## Livré

`API-41` **Le meneur de groupe** est livré en 1.5.0 (`RideGroupDto.leader`, nullable). Les
**gabarits de sortie n'ont volontairement pas de meneur** — décision produit :
`RideTemplateGroupRequest` reste sans champ, instancier une sortie depuis un gabarit ne désigne
personne. Le repli sur `createdBy` est interdit (`API-30`).
