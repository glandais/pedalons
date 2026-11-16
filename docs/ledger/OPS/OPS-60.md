---
id: OPS-60
title: "Générateur de parcours mis en service : image 1.9 et graphe dans la pile partagée, une clé par environnement, premier dépôt lancé à la main"
status: done
done: 2026-11-16
---

## Livré

`OPS-60` **Générateur de parcours mis en service : image 1.9 et graphe dans la pile partagée,
une clé par environnement, premier dépôt lancé à la main** (2026-11-16, sans changement de
contrat ; suite d'`API-206`) — osm-route-details `1.9.0` dans `pedalons-shared`, le graphe des
Pays de la Loire sous `~/shared/data/osm-route-details-graph/` au nom `pdl-2026-11-14`
(`ORD_GRAPH_NAME` dans `~/shared/.env` ; données OSM du 14 novembre 2026, `graph.id`
`4a8ab3fc75a87044`, 1 290 856 nœuds, 1 653 822 arêtes, chargé en 2 s), une
`ROUTE_GENERATOR_NAMESPACE_KEY` distincte dans `~/staging/.env` et `~/prod/.env`, les deux
backends en `15.0.0`. Les quatre fichiers ont d'abord été vérifiés sur un poste par l'image
`1.9.0` en conteneur limité à 2G, puis copiés en 0444 avec leurs sommes SHA-256 contrôlées sur
le serveur. Déclencheur `POST /api/admin/route-generator/overlays/refresh` avec `force`, à
blanc puis pour de bon : staging 4 équipes déposées sur 22 en 21 s, prod 9 sur 18 en 74 s (la
plus grande : 2 726 traces, 703 Mo envoyés, 47 s), aucun échec. Deux générations réelles sur
staging (60 km, curseur à 0,3 puis à 1) : trois propositions chacune, en 1,0 s et 0,7 s, D+
présent. **Mémoire du service** : 238 Mo après le démarrage avec le graphe, 621 Mo après les
treize dépôts et les deux générations, pic à 662 Mo pour une limite de 2G ; l'altitude `full` à
froid en parallèle n'a pas été provoquée, la surveillance continue sous `OPS-58`. Test : aucun
(exploitation), les relevés ci-dessus. **À ne pas défaire** : un graphe arrive toujours sous un
nom neuf, jamais par-dessus un fichier servi ; la clé d'un environnement ne va jamais dans
`~/shared/.env` ni dans un autre environnement ; après un nouveau graphe ou une clé changée,
le déclencheur avec `force` sur chaque environnement, sans attendre la nuit.
