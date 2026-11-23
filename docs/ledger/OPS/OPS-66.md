---
id: OPS-66
title: "Générateur de parcours : osm-route-details 1.14, la planète servie et un budget de 30 s"
status: done
size: "S"
done: 2026-11-23
---

## Livré

`OPS-66` **Générateur de parcours : osm-route-details 1.14, la planète servie et un budget de 30 s** — le
21 novembre 2026, les deux backends attendent le générateur 35 s (`pedalons.route-generator.generate-timeout`,
`PT35S`, au lieu de 10), puis la pile partagée est passée de `1.13.1` à `1.14.0` (`API-207`), d'abord sur la France,
puis sur la planète. La 1.14.0 porte le budget d'une génération de 8 à 30 s pour les villes denses : les parcours ne
changent pas. Elle lit aussi l'index de service `<name>.ordi` à côté du graphe.

- **Fichiers :** les cinq fichiers `planet-261116-20261119-z11.*` (environ 112 Go) sont posés en 0444 sous
  `~/shared/data/osm-route-details-graph/`, avec les mêmes sommes de contrôle que la construction.
- **Bascule :** `ORD_GRAPH_NAME` vaut le nouveau nom, et l'ancien `.env` est gardé à côté. Le service est prêt en
  3,0 s (`index: file`), graphe `916dceff034038a9`, 431,5 millions de nœuds.
- **Contrôle :** des générations en découverte depuis le réseau partagé, en France, à Tokyo, New York, Séoul et
  au Cap, rendent leurs trois propositions en 0,7 à 8,9 s, à pages froides. La mémoire reste sous 1,8 Gio sur 3.

Mesures et validation sur le poste : note `ord-1-14-planete-mesures.md` d'osm-route-details.

- **Surcouches :** le déclencheur avec `force` a redéposé les 10 surcouches de prod le 21 novembre, de 17:39 à
  17:59 UTC (1202 s, 0 échec). La plus grosse équipe a pris 454 s et 704,5 Mo envoyés, comme sur la France. Le
  déclencheur de staging, lancé en même temps, a attendu 120 s derrière ce dépôt puis reçu un 503 qui a arrêté sa
  passe. La passe de nuit du 22 novembre a déposé ses 4 surcouches `STALE` en 348 s ; celle de prod les a toutes
  gardées.
- **Constat :** aucun redémarrage ni OOM du moteur en 24 h, et une génération d'équipe en `team_first` rend ses trois
  parcours en 1,4 s. `docs/OPERATIONS.md` demande désormais de lancer les déclencheurs l'un après l'autre.
- **Ancien graphe :** le moteur a purgé les 14 surcouches de l'ancien graphe le 23 novembre à 02:50 UTC, puis les six
  fichiers `fr-2026-11-15.*` (environ 4,2 Go) ont été supprimés à la main le même jour.
