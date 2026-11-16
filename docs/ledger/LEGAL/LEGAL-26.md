---
id: LEGAL-26
title: "Revêtement des parcours : ODbL et mention de VersaTiles côté serveur"
status: open
size: "S"
verified: 2026-11-16
---

## Reste à faire

`LEGAL-26` **Revêtement des parcours : ODbL et mention de VersaTiles côté serveur (S)** —
deux points relevés par `API-150`, à instruire. (1) Le backend stocke par parcours des plages
typées tirées d'OSM (`TrackSurfaceDocument.ways` : structure, revêtement, type de voie) ; le
contrat d'osm-route-details (§4.7) rappelle qu'un client qui accumule ses réponses en base de
segments relève du partage à l'identique de l'ODbL (déjà vrai avec osm-surface depuis
`OPS-57`) : dire si c'est une base dérivée et ce que ça implique, ou réduire ce qui est gardé.
(2) La politique ne cite VersaTiles que comme fond de carte côté client, alors que le serveur
(osm-surface puis osm-route-details) lui demande des tuiles sur l'emprise des parcours ; sans
objet si la prod passe à un extrait VersaTiles local (`OPS-58`). Parité FR/EN. Décision du
7 novembre 2026 : noter, ne rien changer pour l'instant.
