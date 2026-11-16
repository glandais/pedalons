---
id: SEC-28
title: "Une limite de débit par client devant tout le site : M10"
status: done
done: 2026-09-30
---

## Livré

`SEC-28` **Une limite de débit par client devant tout le site : M10** (2026-09-30, contrat
inchangé, pas de migration ; détaché de `SEC-11`) — rien ne bornait le débit d'un client hors des
compteurs d'authentification (`SEC-4`, `SEC-7`). Décision de l'utilisateur : **au proxy, pas dans
l'application** — un middleware `ratelimit` de Traefik sur chacun des deux routeurs de
`docker-compose.yml`, 50 requêtes/s en rafales de 200 sur `/api`, 100/s en rafales de 400 sur le
site, `429` avec `Retry-After` au-delà. Larges exprès : une carte tire ses tuiles par rafales, une
première visite charge tous les chunks, un club derrière une adresse reste un seul client. Réglables
par `RATE_LIMIT_API_AVERAGE`, `…_BURST`, `RATE_LIMIT_FRONTEND_AVERAGE`, `…_BURST` (`.env.example`) ;
`.env.e2e` les lève, la pile e2e n'ayant rien devant elle. Le client est le **dernier** saut de
`X-Forwarded-For` (`ipStrategy.depth=1`), celui que pose le Caddy de l'hôte, seul point d'entrée,
qui remplace l'en-tête reçu — un premier saut forgé ne change pas de compteur. Vérifié le 30
septembre 2026 sur un Traefik v3.7 jetable (dépassement, `Retry-After`, client voisin intact,
premier saut forgé ignoré), puis **recetté sur l'hôte** le même jour après déploiement, la
vérification d'`OPERATIONS.md` (« Rate limiting ») : 300 requêtes `/api/config` à 50 en parallèle
finissent en `429` (~250 servies, staging comme prod) et 5 s après tout repasse ; le même lot avec
un `X-Forwarded-For` forgé différent à chaque requête est limité pareil ; 1 500 requêtes sur le
site en 5,2 s donnent 872 `200` (400 + 100/s) ; et pendant que 3 000 requêtes d'une adresse
prenaient 2 268 `429`, une seconde machine, d'une autre adresse, a reçu 40 `200` sur 40 : chaque
client a bien son propre compteur. Ne pas prendre le premier saut de l'en-tête, et
ajouter `trusted_proxies` à Caddy si un proxy vient un jour devant lui. `API-27` (lot de
géométries) reste ouvert : cette limite borne le nombre de lots, pas le poids de chacun.
