---
id: OPS-28
title: "Rafraîchissement quotidien des données des relecteurs des stores installé"
status: done
done: 2026-10-06
---

## Livré

`OPS-28` **Rafraîchissement quotidien des données des relecteurs des stores installé**
(2026-10-06, scindé de `MOB-41`) — `store-demo.env`, `store-demo-accounts.json` (0600) et la
ligne de crontab de `pedalons` étaient en place depuis le 3 octobre, mais **le cron n'a jamais
tourné** : `~/logs` n'existait pas, la redirection `>> ~/logs/store-demo.log` échouait et le
shell ne lançait pas le script. Dossier créé, et la ligne d'[`OPERATIONS.md`](../../OPERATIONS.md#store-reviewers-demo-data)
est désormais précédée du `mkdir`. Le premier lancement a ensuite échoué comme prévu par le
runbook : `marketplace-tester@pedalons.fr` n'était plus membre de `vc-du-lac-d-annecy` (403 dans
les journaux le matin même, cause inconnue — quitter un club ne laisse pas d'événement). Remis
`MEMBER` par une insertion SQL dans `user_teams`, puis `seed.py --target prod --refresh` →
`✔ refreshed` (une inscription de plus par club, fil de commentaires des deux sorties des
Glières). Le check Healthchecks n'est pas créé : `OPS-30`. Pas de test automatisé.
