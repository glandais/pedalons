---
id: API-24
title: "URLs d'images signées"
status: open
size: "M"
group: "Cache, fraîcheur et images — quatre briques indépendantes"
verified: 2026-11-16
---

## Reste à faire

`API-24` **URLs d'images signées (M)** — HMAC sur `(chemin, expiration)`. Piège : une URL qui
expire pendant qu'une image est en cache donne une image cassée **sans erreur lisible** ;
prévoir la renégociation client. Même brique que l'imgproxy non signé (`AUD-9`).
