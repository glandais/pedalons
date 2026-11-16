---
id: OPS-30
title: "Check Healthchecks du rafraîchissement des données des relecteurs des stores"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-30` **Check Healthchecks du rafraîchissement des données des relecteurs des stores**
(scindé de `OPS-28`) — `~/.config/pedalons/store-demo.env` n'a pas de `STORE_DEMO_PING_URL` :
le cron tourne sans que personne ne voie qu'il échoue, et il a échoué sans bruit du 3 au
6 octobre 2026, puis de nouveau après le contrat 11.0.0, jusqu'à ce que `MOB-63` atteigne
`~/prod` (passage du 16 octobre à 05:00 : `✔ refreshed`). Créer le check (quotidien, 05:00
Europe/Paris, avec une marge) et ajouter son URL au fichier
([`OPERATIONS.md`](../../OPERATIONS.md#store-reviewers-demo-data)). Taille : XS.
