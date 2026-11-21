---
id: OPS-66
title: "Générateur de parcours : osm-route-details 1.14, la planète servie et un budget de 30 s"
status: open
size: "S"
verified: 2026-11-21
---

## Reste à faire

`OPS-66` **Générateur de parcours : osm-route-details 1.14, la planète servie et un budget de 30 s** — passer la pile
partagée de `1.13.1` à `1.14.0` (`API-207`), qui porte le budget d'une génération de 8 à 30 s pour les villes denses de
la planète, et lit l'index de service `<name>.ordi` à côté du graphe. Le backend attend désormais 35 s
(`pedalons.route-generator.generate-timeout`, `PT35S`), à déployer avant ou avec le moteur. Puis servir la planète :
les cinq fichiers `planet-261116-20261119-z11.*` sous `~/shared/data/osm-route-details-graph/` (environ 112 Go),
`ORD_GRAPH_NAME` changé, `deploy.sh --shared`, puis le déclencheur avec `force` sur chaque environnement, en relevant la
durée des dépôts et la mémoire du service. Mesures et validation sur le poste : note
`ord-1-14-planete-mesures.md` d'osm-route-details.
