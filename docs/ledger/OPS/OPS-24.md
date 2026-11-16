---
id: OPS-24
title: "`next` et `Referer` masqués dans le journal de Caddy"
status: done
done: 2026-09-30
---

## Livré

`OPS-24` **`next` et `Referer` masqués dans le journal de Caddy** (2026-09-30) — un lien d'export
ouvert sans session renvoie vers `/login?next=/api/export/download?token=…` : le jeton, dans la
*valeur* de `next`, échappait à `replace token`, et les ressources de la page de connexion
repartaient avec l'URL entière en `Referer` (`API-45`). Le Caddyfile de l'hôte a reçu les deux
lignes du snippet `pedalons_access_log` d'[`OPERATIONS.md`](../../OPERATIONS.md#access-logs),
`replace next REDACTED` et `request>headers>Referer delete`, puis `caddy validate`, `chown
caddy:caddy` des fichiers de journal et rechargement ; vérifié par le propriétaire avec
`curl …/login?next=/x?token=abc -H 'Referer: …?token=abc'`, dont la ligne ne porte plus le
jeton. Le snippet sert la prod et le staging. Pas de test automatisé (configuration de l'hôte,
hors dépôt) : ne pas retirer ces lignes, ni ajouter un paramètre porteur de jeton sans son
`replace`.
