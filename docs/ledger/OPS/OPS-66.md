---
id: OPS-66
title: "Générateur de parcours : osm-route-details 1.14, la planète servie et un budget de 30 s"
status: open
size: "S"
verified: 2026-11-21
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

## Reste à faire

- **Redéposer les surcouches :** celles de la France sont `stale` depuis la bascule, donc les générations sous la
  découverte répondent `GENERATOR_NETWORK_NOT_READY`. Il faut lancer le déclencheur avec `force` sur chaque
  environnement, ce qui demande une session d'admin de la plateforme. À défaut, la passe de nuit les redépose.
- **Relever pendant ce premier dépôt :** sa durée et le pic mémoire du service, puis constater qu'une équipe est
  servie avec ses routes.
- **Supprimer les fichiers `fr-2026-11-15.*` :** à la main, quand le moteur aura purgé les surcouches de l'ancien
  graphe, 48 h après.
