---
id: OPS-43
title: "Mise à jour des données Valhalla sans coupure du routage"
status: done
done: 2026-10-16
---

## Livré

`OPS-43` **Mise à jour des données Valhalla sans coupure du routage** (2026-10-16, livré dans le
dépôt ; la stack partagée doit être redéployée par `scripts/deploy.sh --shared` pour en profiter) —
le service `valhalla` de `docker-compose.shared.yml` reçoit un healthcheck (`curl /status`) et
`update_config` start-first avec rollback ; la procédure « Updating the shared Valhalla data » de
`OPERATIONS.md` (retirée avec le service le 17 octobre 2026, `OPS-48`) construisait les tuiles dans
`data/valhalla-next` par un conteneur jetable (`serve_tiles=False`, même image par digest), puis
bascule par deux `mv` et un `docker service update --force`. Corrige aussi une affirmation fausse
de la doc et des commentaires : l'image fixe `use_tiles_ignore_pbf=True`, si bien qu'un changement de
`tile_urls` ou du `.pbf` ne reconstruit **rien** une fois des tuiles présentes. Pas de test :
`docker compose config` et `docker stack config` acceptent le fichier, la commande du healthcheck
rend 0 dans le conteneur de prod. **À ne pas défaire** : le healthcheck compte pour sain un
conteneur sans `valhalla_tiles.tar` (il construit ses premières tuiles), sans quoi Docker tuerait
ce build de plusieurs heures ; et pas de `force_rebuild` sur le service, que ce même healthcheck
tuerait puisque l'ancien `.tar` est encore là.
