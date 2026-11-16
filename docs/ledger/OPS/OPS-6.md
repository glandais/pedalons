---
id: OPS-6
title: "Journal d'accès de l'hôte masqué et borné à 14 jours"
status: done
done: 2026-09-29
---

## Livré

`OPS-6` **Journal d'accès de l'hôte masqué et borné à 14 jours** (2026-09-29) — le Caddy de
l'hôte de production journalise `pedalons.fr` (redirection), `www.pedalons.fr` (l'application)
et les deux domaines de staging, par le snippet `pedalons_access_log` d'
[`OPERATIONS.md`](../../OPERATIONS.md#access-logs) : `t`, `token`, `code`, `state` → `REDACTED`,
coordonnées supprimées, **et `resp_headers>Location` supprimé** — sans lui, la ligne d'une
redirection gardait la query brute dans l'en-tête. Un fichier par pile
(`pedalons-access.log`, `pedalons-staging-access.log`), rotation par
`/etc/logrotate.d/caddy-access`. Vérifié par `curl …?lat=1&t=x` sur les trois domaines :
`t=REDACTED`, pas de `lat`, pas de `Location`. Sauvegarde de l'ancienne config :
`/etc/caddy/Caddyfile.bak-20260929`. Les jetons dans le **chemin** restent en clair : `API-45`.
Ne pas retirer la ligne `Location`, et refaire le `chown caddy:caddy` des fichiers après tout
`caddy validate` lancé en root. Pas de test (configuration hors dépôt).
