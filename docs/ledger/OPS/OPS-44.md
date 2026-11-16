---
id: OPS-44
title: "Un test automatisé pour « `AdDto` ne porte aucun champ de contact »"
status: open
group: "Recette du backend en conditions réelles"
verified: 2026-11-16
---

## Reste à faire

`OPS-44` **Un test automatisé pour « `AdDto` ne porte aucun champ de contact »** —
l'invariant (relais d'e-mail, aucune adresse dans l'API) n'est gardé que par le `grep` et le
script Python du §5.3 du
[document d'API](../../plans/archive/2026-07-26-api-v2-livraison-et-suites.md), à lancer à la main
(rejoués le 16 octobre 2026 sur le contrat `11.5.1` : `OPS-5`). Le jour où un champ de
contact y entre, une adresse personnelle est publiée à toute une équipe, irrévocablement, et
aucun build ne le voit. En faire un test backend qui lit le schéma OpenAPI généré (ou les
composants du record `AdDto`) et échoue sur `contact|email|phone|mail|tel`. Taille : XS.
