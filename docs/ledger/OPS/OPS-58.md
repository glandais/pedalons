---
id: OPS-58
title: "osm-route-details dans la pile partagée : à régler"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-58` **osm-route-details dans la pile partagée : à régler** — en service depuis le
7 novembre 2026 en staging et en prod (osm-surface retiré, `OPS-59`). Faits depuis : limite
mémoire à 2 Go (`docker-compose.shared.yml`), service dans les cibles Prometheus (`:9090`),
image `1.9.0` avec le graphe du générateur (`OPS-60`). La saturation mesurée le 10 novembre
2026 (977 Mo sur 1 Go, ~475 Mo de swap, requêtes de 20 à 45 s) venait du
`RouteDetailsBackfill`, retiré le même jour (`API-174`) ; au 16 novembre 2026 la prod est à
621 Mo après treize dépôts de surcouche et deux générations, pic à 662 Mo
(`docs/OPERATIONS.md`). Reste : l'extrait VersaTiles France en fichier local, le volume de
cache à dimensionner (IGN, Mapterhorn, VersaTiles), et suivre la mémoire quelques semaines
avant de dire la limite juste — si elle remonte sans charge, c'est une fuite à remonter dans
osm-route-details. Plan :
[2026-11-05-osm-route-details](../../plans/2026-11-05-osm-route-details.md) §11.
