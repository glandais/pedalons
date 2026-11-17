---
id: OPS-61
title: "Générateur de parcours : graphe de la France dans la pile partagée (S, exploitation)"
status: open
size: "S"
kind: externe
group: "Exploitation"
verified: 2026-11-17
---

## Reste à faire

`OPS-61` **Générateur de parcours : graphe de la France dans la pile partagée (S, exploitation)** — le
moteur `1.9.1` (`API-207`, lot 6) sert la France entière, mais la pile partagée porte encore le graphe
des Pays de la Loire : une équipe d'une autre région reçoit « hors zone ». À faire à la main : déployer
la pile partagée en `1.9.1`, poser les quatre fichiers de la France (1,85 + 0,87 + 1,43 Go et le
polygone ; construits sur un poste, données OSM du 15 novembre 2026) sous un nom neuf dans
`~/shared/data/osm-route-details-graph/`, changer `ORD_GRAPH_NAME`, redéployer, puis le déclencheur
avec `force` sur staging et prod. À mesurer sur le serveur, parce que le poste ne l'a pas fait : la
mémoire avec l'altitude sollicitée en même temps (1,10 Go d'anonyme mesurés pour le générateur seul
avec 18 équipes ; l'altitude seule est montée à 1,4 Go avec le swap le 10 novembre 2026, `OPS-58`),
que la limite du conteneur, passée de 2G à 3G le 17 novembre 2026 sur décision du propriétaire, doit couvrir ; le démarrage (8,5 s sur le poste) et la première
génération sur le disque du serveur. Procédure : `docs/OPERATIONS.md`.
