---
id: OPS-19
title: "PostgreSQL 17 → 18 : image, volume et script de bascule"
status: done
done: 2026-10-25
---

## Livré

`OPS-19` **PostgreSQL 17 → 18 : image, volume et script de bascule** (2026-10-25, livré dans le
dépôt ; chaque environnement bascule par `OPS-53`) — `docker-compose.yml` passe à
`imresamu/postgis:18-3.6-alpine` sur un **nouveau** volume, `pg_clusters`, monté sur
`/var/lib/postgresql` : l'image 18 refuse de démarrer sur l'ancien montage `…/data`, et aussi sur
le volume 17 remonté au nouveau point (vérifié le 25 octobre 2026). `scripts/postgres-upgrade.sh`
arrête backend, frontend et goatcounter, copie toutes les bases et tous les rôles par
`pg_dumpall` dans un conteneur 18 jetable (initialisé vide : sans `POSTGRES_DB` ni scripts
d'init PostGIS, pour que seule la création du superutilisateur entre en conflit avec le dump),
compare bases, extensions et nombre de lignes de chaque table des deux côtés, puis bascule
(`deploy.sh` sur un hôte, `docker compose up -d postgres` sur un poste) ; avant la bascule, tout
échec jette la copie et relance les écrivains sur l'ancien volume. `deploy.sh` refuse de déployer
tant que le service postgres tourne sur un autre volume que `pg_clusters` : il démarrerait la 18
sur un volume vide, où le backend amorcerait un Domain neuf (le script le lance avec
`POSTGRES_UPGRADE=1`). Rejoué sur une pile jetable :
copie (5 bases, 76 tables, PostGIS 3.6.1, rôle GoatCounter et son mot de passe SCRAM conservés),
relance refusée, échec simulé, retour arrière en 17 sur l'ancien volume intact. Procédure dans
`OPERATIONS.md`, « PostgreSQL major upgrade » ; `restore.sh` vide désormais `pg_clusters`.
À ne pas défaire : **un nouveau volume à chaque changement de montage**, l'ancien jamais écrit
(c'est lui, avec le commit précédent, qui fait le retour arrière) ; **`pg_dumpall`, pas
`backup.sh` + `restore.sh`**, qui ne sauvegardent que `$POSTGRES_DB` et perdraient GoatCounter.
Le montage sur `/var/lib/postgresql` permettra à la prochaine majeure un `pg_upgrade --link` dans
le même volume. Couvert par la suite backend, qui tourne sur l'image du compose
(`DevServicesImageConfigSource`).
